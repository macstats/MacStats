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
}

struct DiskStats {
    var totalBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var usedBytes: UInt64 { totalBytes - freeBytes }

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
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
    var thermalLevel = ThermalLevel.nominal
}
