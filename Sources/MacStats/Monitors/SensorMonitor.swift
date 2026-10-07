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

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
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

    /// Apple Silicon performance/efficiency cores first, then Intel sensors.
    private let temperatureKeys = [
        "Tp09", "Tp05", "Tp01", "Tp0D", "Tp0b", "Tp0f",
        "TC0P", "TC0D", "TC0E", "TC0F",
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
                      let rpm = decodeFPE2(actual.bytes) else { continue }
                var fan = FanStats(index: index, rpm: rpm)
                if let minReading = readKey(conn, "F\(index)Mn"), let minRPM = decodeFPE2(minReading.bytes) {
                    fan.minRPM = minRPM
                }
                if let maxReading = readKey(conn, "F\(index)Mx"), let maxRPM = decodeFPE2(maxReading.bytes) {
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

        let dataSize = infoOutput.keyInfo.dataSize
        guard dataSize > 0, dataSize <= 32 else { return nil }

        var readInput = SMCKeyData()
        readInput.key = code
        readInput.keyInfo.dataSize = dataSize
        readInput.data8 = Self.commandReadBytes
        guard let readOutput = call(conn, &readInput) else { return nil }

        let bytes = withUnsafeBytes(of: readOutput.bytes) { Array($0.prefix(Int(dataSize))) }
        return (dataSize, infoOutput.keyInfo.dataType, bytes)
    }

    // MARK: - Decoding

    private func decodeTemperature(bytes: [UInt8], type: UInt32) -> Double? {
        switch typeString(type) {
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return Double(Int8(bitPattern: bytes[0])) + Double(bytes[1]) / 256.0
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            let value = Double(Float(bitPattern: bits))
            return value.isFinite ? value : nil
        default:
            return nil
        }
    }

    /// fpe2: unsigned 14.2 fixed point (fan RPM).
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
