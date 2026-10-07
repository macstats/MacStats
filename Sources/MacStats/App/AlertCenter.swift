import Foundation

enum AlertSeverity: String {
    case warning
    case critical
}

/// One currently-active threshold breach, rendered by `AlertBannerView`.
struct ActiveAlert: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let severity: AlertSeverity
}

/// Threshold evaluation + native notification delivery.
///
/// CONTRACT (frozen by root):
///   - class name: `AlertCenter`
///   - `isEnabled` persists in UserDefaults (key `MacStats.alertsEnabled`, default true)
///   - `func evaluate(_ stats: SystemStats) -> [ActiveAlert]` is called on the monitor
///     queue on every tick and returns the set of alerts that are active right now.
///     It must be cheap, thread-safe, and must not deliver more than one notification
///     per condition per cooldown window.
///   - `requestAuthorization()` / `postTestNotification()` are called from the main
///     thread and must no-op safely when running unbundled (no bundle identifier).
final class AlertCenter {
    private let enabledKey = "MacStats.alertsEnabled"
    private let defaults: UserDefaults
    private let allowsNotifications: Bool

    init(postsNotifications: Bool = true, defaults: UserDefaults = .standard) {
        self.allowsNotifications = postsNotifications
        self.defaults = defaults
        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(true, forKey: enabledKey)
        }
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    func evaluate(_ stats: SystemStats) -> [ActiveAlert] {
        []
    }

    func requestAuthorization() {}

    func postTestNotification() {}
}
