import Foundation

struct TopProcess: Equatable, Identifiable {
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memPercent: Double
    var residentBytes: UInt64 = 0
    var executablePath: String = ""

    var id: Int32 { pid }
}

/// Which column the process list is ranked by.
enum ProcessSortKey: String, CaseIterable, Equatable {
    case cpu
    case memory

    var label: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        }
    }
}
