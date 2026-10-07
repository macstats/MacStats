import Foundation
import IOKit
import Darwin

// MARK: - AppleSMC structures (must match smc.c byte for byte)

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

/// `SMCKeyData_t` flattened with explicit padding so the Swift layout matches the
/// C struct byte for byte (80 bytes). Nested Swift structs are packed by size
/// rather than by C stride, which silently produced a 76-byte struct and made
/// every IOConnectCallStructMethod return `kIOReturnBadArgument`.
///
/// C layout: key(0) vers(4..10) pLimitData(12..28) keyInfo(28..40)
///           result(40) status(41) data8(42) data32(44) bytes(48..80)
private struct SMCKeyData {
    var key: UInt32 = 0                 // 0
    var versMajor: UInt8 = 0            // 4
    var versMinor: UInt8 = 0            // 5
    var versBuild: UInt8 = 0            // 6
    var versReserved: UInt8 = 0         // 7
    var versRelease: UInt16 = 0         // 8
    var pad0: UInt16 = 0                // 10 — aligns pLimitData to 12
    var plimitVersion: UInt16 = 0       // 12
    var plimitLength: UInt16 = 0        // 14
    var plimitCPU: UInt32 = 0           // 16
    var plimitGPU: UInt32 = 0           // 20
    var plimitMem: UInt32 = 0           // 24
    var infoDataSize: UInt32 = 0        // 28
    var infoDataType: UInt32 = 0        // 32
    var infoAttributes: UInt8 = 0       // 36
    var pad1: UInt8 = 0                 // 37
    var pad2: UInt8 = 0                 // 38
    var pad3: UInt8 = 0                 // 39
    var result: UInt8 = 0               // 40
    var status: UInt8 = 0               // 41
    var data8: UInt8 = 0                // 42
    var pad4: UInt8 = 0                 // 43
    var data32: UInt32 = 0              // 44
    var bytes: SMCBytes = (             // 48 .. 80
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

/// Reads thermal / fan sensors from the AppleSMC user client.
///
/// Key sets are probed for both Apple Silicon and Intel machines; any failure
/// (service missing, unprivileged user client, unknown key, short read) degrades
/// to `SensorStats()` or a partially filled result instead of crashing.
final class SensorMonitor {
    private static let kernelIndexSMC: UInt32 = 2
    private static let commandReadBytes: UInt8 = 5
    private static let commandReadKeyInfo: UInt8 = 9

    /// CPU-ish sensors, most specific first:
    /// Apple Silicon `Tp0*` cores → newer-SMC `Tc0*`/`TCM*` clusters →
    /// Intel `TC0*` proximity/die → heat pipe / PMU fallbacks.
    private let temperatureKeys = [
        "Tp09", "Tp05", "Tp01", "Tp0D", "Tp0b", "Tp0f",
        "Tc0x", "Tc0z", "Tc0a", "Tc0b", "TCMz", "TCMb",
        "TC0P", "TC0D", "TC0E", "TC0F",
        "TCHP", "TPMP", "TPSP",
    ]

    func read() -> SensorStats {
        // A layout mismatch would silently corrupt every call — refuse to run.
        guard MemoryLayout<SMCKeyData>.stride == 80 else { return SensorStats() }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else { return SensorStats() }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else {
            return SensorStats()
        }
        defer { IOServiceClose(conn) }

        var stats = SensorStats()

        for key in temperatureKeys {
            guard let reading = readKey(conn, key),
                  let celsius = decodeTemperature(bytes: reading.bytes, type: reading.dataType),
                  celsius > 0, celsius < 130 else { continue }
            stats.cpuTemperature = celsius
            stats.temperatureKey = key
            stats.isAvailable = true
            break
        }

        if let fanCountReading = readKey(conn, "FNum"),
           let fanCount = decodeUInt8(fanCountReading.bytes),
           fanCount > 0 {
            var fans: [FanStats] = []
            for index in 0..<min(Int(fanCount), 4) {
                guard let actual = readKey(conn, "F\(index)Ac"),
                      let rpm = decodeFanRPM(bytes: actual.bytes, type: actual.dataType) else { continue }
                var fan = FanStats(index: index, rpm: rpm)
                if let minReading = readKey(conn, "F\(index)Mn"),
                   let minRPM = decodeFanRPM(bytes: minReading.bytes, type: minReading.dataType) {
                    fan.minRPM = minRPM
                }
                if let maxReading = readKey(conn, "F\(index)Mx"),
                   let maxRPM = decodeFanRPM(bytes: maxReading.bytes, type: maxReading.dataType) {
                    fan.maxRPM = maxRPM
                }
                fans.append(fan)
            }
            if !fans.isEmpty {
                stats.fans = fans
                stats.isAvailable = true
            }
        }

        return stats
    }

    // MARK: - SMC calls

    private func call(_ conn: io_connect_t, _ input: inout SMCKeyData) -> SMCKeyData? {
        var output = SMCKeyData()
        var outputSize = MemoryLayout<SMCKeyData>.stride
        let result = IOConnectCallStructMethod(
            conn,
            Self.kernelIndexSMC,
            &input,
            MemoryLayout<SMCKeyData>.stride,
            &output,
            &outputSize
        )
        guard result == kIOReturnSuccess else { return nil }
        return output
    }

    private func readKey(_ conn: io_connect_t, _ key: String) -> (dataSize: UInt32, dataType: UInt32, bytes: [UInt8])? {
        let code = fourCC(key)

        var infoInput = SMCKeyData()
        infoInput.key = code
        infoInput.data8 = Self.commandReadKeyInfo
        guard let infoOutput = call(conn, &infoInput) else { return nil }

        let dataSize = infoOutput.infoDataSize
        guard dataSize > 0, dataSize <= 32 else { return nil }

        var readInput = SMCKeyData()
        readInput.key = code
        readInput.infoDataSize = dataSize
        readInput.data8 = Self.commandReadBytes
        guard let readOutput = call(conn, &readInput) else { return nil }

        let bytes = withUnsafeBytes(of: readOutput.bytes) { Array($0.prefix(Int(dataSize))) }
        return (dataSize, infoOutput.infoDataType, bytes)
    }

    // MARK: - Decoding

    private func decodeTemperature(bytes: [UInt8], type: UInt32) -> Double? {
        switch typeString(type) {
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return Double(Int8(bitPattern: bytes[0])) + Double(bytes[1]) / 256.0
        case "flt ":
            return decodeFloat(bytes)
        default:
            return nil
        }
    }

    /// `flt ` is big-endian IEEE 754 on Intel SMC firmware and little-endian on
    /// the Apple Silicon SMC; pick whichever interpretation is plausible.
    private func decodeFloat(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 4 else { return nil }
        let bigEndianBits = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        let littleEndianBits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        let big = Double(Float(bitPattern: bigEndianBits))
        let little = Double(Float(bitPattern: littleEndianBits))

        // A denormalized byte pattern (e.g. 1e-38) is technically finite and
        // positive, so require a physically sensible temperature range.
        let bigPlausible = big.isFinite && big >= 5 && big <= 130
        let littlePlausible = little.isFinite && little >= 5 && little <= 130

        if bigPlausible { return big }
        if littlePlausible { return little }
        return nil
    }

    /// Fan keys are `flt ` on Apple Silicon and `fpe2`/`ui16` on older Intel SMC.
    private func decodeFanRPM(bytes: [UInt8], type: UInt32) -> Int? {
        switch typeString(type) {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let littleEndianBits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            let bigEndianBits = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            let little = Double(Float(bitPattern: littleEndianBits))
            let big = Double(Float(bitPattern: bigEndianBits))
            let candidates = [little, big].filter { $0.isFinite && $0 >= 0 && $0 <= 20000 }
            if let spinning = candidates.first(where: { $0 >= 200 }) { return Int(spinning.rounded()) }
            if let stopped = candidates.first { return Int(stopped.rounded()) }
            return nil
        case "fpe2":
            return decodeFPE2(bytes)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Int(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        default:
            return decodeFPE2(bytes)
        }
    }

    /// fpe2: unsigned 14.2 fixed point (legacy fan RPM).
    private func decodeFPE2(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 2 else { return nil }
        return (Int(bytes[0]) << 8 | Int(bytes[1])) / 4
    }

    private func decodeUInt8(_ bytes: [UInt8]) -> UInt8? {
        bytes.first
    }

    private func fourCC(_ string: String) -> UInt32 {
        var value: UInt32 = 0
        for byte in string.utf8.prefix(4) {
            value = (value << 8) | UInt32(byte)
        }
        return value
    }

    private func typeString(_ type: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((type >> 24) & 0xFF),
            UInt8((type >> 16) & 0xFF),
            UInt8((type >> 8) & 0xFF),
            UInt8(type & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
}
