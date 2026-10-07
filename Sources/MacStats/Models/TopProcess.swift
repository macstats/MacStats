import Foundation

struct TopProcess {
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memPercent: Double
    var residentBytes: UInt64 = 0
    var executablePath: String = ""
}

/// Sort key used by the process browser.
enum ProcessSortMode: String, CaseIterable, Identifiable {
    case cpu
    case memory

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        }
    }
}
