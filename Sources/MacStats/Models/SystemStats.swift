import Foundation

/// 1/5/15-minute load averages.
struct LoadAverage: Equatable {
    var one: Double = 0
    var five: Double = 0
    var fifteen: Double = 0
}

struct CPUStats: Equatable {
    var totalUsage: Double = 0.0
    var perCoreUsage: [Double] = []
    var load = LoadAverage()
    var coreCount: Int { perCoreUsage.count }

    /// Index of the busiest core, if there is one.
    var busiestCore: (index: Int, usage: Double)? {
        guard let maxUsage = perCoreUsage.max(), maxUsage > 0,
              let index = perCoreUsage.firstIndex(of: maxUsage) else { return nil }
        return (index, maxUsage)
    }
}

/// `kern.memorystatus_vm_pressure_level`, surfaced by `DispatchSource`.
enum MemoryPressure: Int, Equatable {
    case normal = 1
    case warning = 2
    case critical = 4

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    var level: StatusLevel {
        switch self {
        case .normal: return .normal
        case .warning: return .elevated
        case .critical: return .critical
        }
    }
}

struct MemoryStats: Equatable {
    var totalBytes: UInt64 = 0
    var usedBytes: UInt64 = 0
    var activeBytes: UInt64 = 0
    var wiredBytes: UInt64 = 0
    var compressedBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var pressure: MemoryPressure = .normal

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
}

struct NetworkStats: Equatable {
    var bytesSentPerSec: Double = 0
    var bytesReceivedPerSec: Double = 0
    /// Totals since the app launched — useful for spotting heavy transfers.
    var sessionSentBytes: UInt64 = 0
    var sessionReceivedBytes: UInt64 = 0
}

struct DiskStats: Equatable {
    var totalBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var volumeName: String = "Macintosh HD"
    var usedBytes: UInt64 { totalBytes - freeBytes }

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
}

struct BatteryStats: Equatable {
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

struct WiFiStats: Equatable {
    var isActive: Bool = false
    var ssid: String = ""
    var rssi: Int = 0            // dBm, typically -30 (best) to -90 (worst)
    var channel: Int = 0
    var localIP: String = ""
    var interfaceName: String = ""
    var transmitRateMbps: Double = 0

    /// Signal quality 0–4 bars derived from RSSI
    var signalBars: Int {
        if rssi >= -50 { return 4 }
        if rssi >= -60 { return 3 }
        if rssi >= -70 { return 2 }
        if rssi >= -80 { return 1 }
        return 0
    }

    /// Signal quality as a status level for consistent coloring.
    var signalLevel: StatusLevel {
        switch signalBars {
        case 4, 3: return .normal
        case 2: return .elevated
        default: return .critical
        }
    }

    var bandLabel: String {
        guard channel > 0 else { return "—" }
        if channel <= 14 { return "2.4 GHz" }
        if channel <= 177 { return "5 GHz" }
        return "6 GHz"
    }
}

/// Maps to ProcessInfo.ThermalState
enum ThermalLevel: Int, Equatable {
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

    var level: StatusLevel {
        switch self {
        case .nominal:  return .normal
        case .fair:     return .normal
        case .serious:  return .elevated
        case .critical: return .critical
        }
    }

    var symbol: String {
        switch self {
        case .nominal:  return "thermometer.low"
        case .fair:     return "thermometer.medium"
        case .serious:  return "thermometer.high"
        case .critical: return "flame.fill"
        }
    }
}

struct SystemStats: Equatable {
    var cpu = CPUStats()
    var memory = MemoryStats()
    var network = NetworkStats()
    var disk = DiskStats()
    var battery = BatteryStats()
    var wifi = WiFiStats()
    var thermalLevel = ThermalLevel.nominal
}
