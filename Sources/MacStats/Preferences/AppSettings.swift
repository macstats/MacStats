import Combine
import Foundation

/// User-facing preferences, persisted in `UserDefaults`.
///
/// Everything the scheduler needs is a plain value, so both the view model
/// and the status bar controller can observe the same object without
/// touching each other.
final class AppSettings: ObservableObject {

    enum MenuBarStyle: String, CaseIterable, Identifiable {
        case full      // CPU + memory + up/down + trace
        case compact   // CPU + memory + trace
        case minimal   // CPU + trace
        case chart     // trace only

        var id: String { rawValue }

        var label: String {
            switch self {
            case .full: return "CPU, Memory & Network"
            case .compact: return "CPU & Memory"
            case .minimal: return "CPU Only"
            case .chart: return "History Chart Only"
            }
        }
    }

    enum RefreshRate: Double, CaseIterable, Identifiable {
        case fast = 2
        case balanced = 3
        case relaxed = 5
        case eco = 10

        var id: Double { rawValue }
        var seconds: TimeInterval { rawValue }

        var label: String {
            switch self {
            case .fast: return "Fast — 2s"
            case .balanced: return "Balanced — 3s"
            case .relaxed: return "Relaxed — 5s"
            case .eco: return "Eco — 10s"
            }
        }
    }

    private enum Key {
        static let menuBarStyle = "menuBarStyle"
        static let refreshRate = "refreshRateSeconds"
        static let processSort = "processSortKey"
    }

    private let defaults: UserDefaults

    @Published var menuBarStyle: MenuBarStyle {
        didSet { defaults.set(menuBarStyle.rawValue, forKey: Key.menuBarStyle) }
    }

    @Published var refreshRate: RefreshRate {
        didSet { defaults.set(refreshRate.rawValue, forKey: Key.refreshRate) }
    }

    @Published var processSort: ProcessSortKey {
        didSet { defaults.set(processSort.rawValue, forKey: Key.processSort) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        menuBarStyle = MenuBarStyle(rawValue: defaults.string(forKey: Key.menuBarStyle) ?? "") ?? .full
        refreshRate = RefreshRate(rawValue: defaults.double(forKey: Key.refreshRate)) ?? .balanced
        processSort = ProcessSortKey(rawValue: defaults.string(forKey: Key.processSort) ?? "") ?? .cpu
    }
}
