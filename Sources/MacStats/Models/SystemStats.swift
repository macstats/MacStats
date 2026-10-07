import Foundation

struct CPUStats {
    var totalUsage: Double = 0.0
    var perCoreUsage: [Double] = []
    var coreCount: Int { perCoreUsage.count }
}

struct MemoryStats {
    var totalBytes: UInt64 = 0
    var usedBytes: UInt64 = 0
    var activeBytes: UInt64 = 0
    var wiredBytes: UInt64 = 0
    var compressedBytes: UInt64 = 0
    var freeBytes: UInt64 = 0

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
}

struct NetworkStats {
    var bytesSentPerSec: Double = 0
    var bytesReceivedPerSec: Double = 0
    /// Totals accumulated since MacStats launched (not since boot).
    var sessionSentBytes: UInt64 = 0
    var sessionReceivedBytes: UInt64 = 0
    /// Highest rates observed since launch.
    var peakSentPerSec: Double = 0
    var peakReceivedPerSec: Double = 0
}

struct DiskStats {
    var totalBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    /// Live throughput derived from IOBlockStorageDriver statistics.
    var readBytesPerSec: Double = 0
    var writeBytesPerSec: Double = 0
    /// Totals accumulated since MacStats launched.
    var sessionReadBytes: UInt64 = 0
    var sessionWriteBytes: UInt64 = 0
    var usedBytes: UInt64 { totalBytes > freeBytes ? totalBytes - freeBytes : 0 }

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
}

struct GPUStats {
    var isAvailable: Bool = false
    var name: String = ""
    var utilizationPercent: Double = 0
    var memoryUsedBytes: UInt64 = 0
    var memoryTotalBytes: UInt64 = 0
    var coreCount: Int = 0

    var memoryUsagePercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return Double(memoryUsedBytes) / Double(memoryTotalBytes) * 100.0
    }
}

struct FanStats: Identifiable {
    var index: Int = 0
    var rpm: Int = 0
    var minRPM: Int = 0
    var maxRPM: Int = 0

    var id: Int { index }
}

struct SensorStats {
    var isAvailable: Bool = false
    /// CPU (or proximity) temperature in Celsius, nil when unavailable.
    var cpuTemperature: Double? = nil
    /// SMC key that produced `cpuTemperature` — handy for debugging.
    var temperatureKey: String = ""
    var fans: [FanStats] = []
}

struct ConnectionStats {
    var isAvailable: Bool = false
    var established: Int = 0
    var listening: Int = 0
    var timeWait: Int = 0
    var closeWait: Int = 0
    var other: Int = 0
    var listeningPorts: [Int] = []

    var total: Int { established + listening + timeWait + closeWait + other }
}

struct BatteryStats {
    var isPresent: Bool = false
    var currentCapacity: Int = 0
    var maxCapacity: Int = 0
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var timeToEmpty: Int = -1      // minutes, -1 = unknown
    var timeToFull: Int = -1       // minutes, -1 = unknown
    var cycleCount: Int = 0
    var designCapacity: Int = 0    // mAh
    var healthPercent: Double = 0  // maxCapacity / designCapacity * 100
    var temperature: Double = 0    // Celsius

    var chargePercent: Double {
        guard maxCapacity > 0 else { return 0 }
        return Double(currentCapacity) / Double(maxCapacity) * 100.0
    }
}

struct WiFiStats {
    var isActive: Bool = false
    var ssid: String = ""
    var rssi: Int = 0            // dBm, typically -30 (best) to -90 (worst)
    var channel: Int = 0
    var localIP: String = ""
    var interfaceName: String = ""

    /// Signal quality 0–4 bars derived from RSSI
    var signalBars: Int {
        if rssi >= -50 { return 4 }
        if rssi >= -60 { return 3 }
        if rssi >= -70 { return 2 }
        if rssi >= -80 { return 1 }
        return 0
    }
}

/// Maps to ProcessInfo.ThermalState
enum ThermalLevel: Int {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3

    var label: String {
        switch self {
        case .nominal:  return "Normal"
        case .fair:     return "Fair"
        case .serious:  return "Serious"
        case .critical: return "Critical"
        }
    }
}

struct SystemStats {
    var cpu = CPUStats()
    var memory = MemoryStats()
    var network = NetworkStats()
    var disk = DiskStats()
    var battery = BatteryStats()
    var wifi = WiFiStats()
    var gpu = GPUStats()
    var sensors = SensorStats()
    var connections = ConnectionStats()
    var thermalLevel = ThermalLevel.nominal
}
