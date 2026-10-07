import Foundation
import UserNotifications

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
/// `evaluate(_:)` runs on the monitor queue every 3s, so all mutable state is
/// guarded by a lock and notifications are rate-limited per condition.
final class AlertCenter {
    struct Thresholds {
        var cpuPercent: Double = 90
        var memoryPercent: Double = 90
        var diskPercent: Double = 92
        var batteryPercent: Double = 20
        /// CPU must stay above the threshold for this many consecutive samples.
        var cpuSustainedTicks: Int = 2
        /// One notification per condition per cooldown window.
        var cooldown: TimeInterval = 600
        /// Tick length, used to phrase "for Ns" in messages.
        var tickSeconds: Int = 3
    }

    private let enabledKey = "MacStats.alertsEnabled"
    private let defaults: UserDefaults
    private let allowsNotifications: Bool
    private let thresholds = Thresholds()

    private let lock = NSLock()
    private var cpuStreak = 0
    private var lastDelivered: [String: Date] = [:]

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
        lock.lock()
        defer { lock.unlock() }

        guard isEnabled else {
            cpuStreak = 0
            return []
        }

        if stats.cpu.totalUsage >= thresholds.cpuPercent {
            cpuStreak += 1
        } else {
            cpuStreak = 0
        }

        var alerts: [ActiveAlert] = []

        if cpuStreak >= thresholds.cpuSustainedTicks {
            alerts.append(ActiveAlert(
                id: "cpu",
                title: "CPU overloaded",
                message: String(
                    format: "CPU at %.1f%% for %ds",
                    stats.cpu.totalUsage,
                    cpuStreak * thresholds.tickSeconds
                ),
                severity: .critical
            ))
        }

        if stats.memory.usagePercent >= thresholds.memoryPercent {
            alerts.append(ActiveAlert(
                id: "memory",
                title: "Memory pressure",
                message: String(format: "Memory at %.1f%%", stats.memory.usagePercent),
                severity: .warning
            ))
        }

        if stats.disk.totalBytes > 0, stats.disk.usagePercent >= thresholds.diskPercent {
            alerts.append(ActiveAlert(
                id: "disk",
                title: "Disk almost full",
                message: String(format: "%.1f%% used — %.0f GB free",
                                stats.disk.usagePercent,
                                Double(stats.disk.freeBytes) / (1024 * 1024 * 1024)),
                severity: .warning
            ))
        }

        if stats.battery.isPresent, !stats.battery.isPluggedIn,
           stats.battery.chargePercent < thresholds.batteryPercent {
            alerts.append(ActiveAlert(
                id: "battery",
                title: "Battery low",
                message: String(format: "%.0f%% left — plug in soon", stats.battery.chargePercent),
                severity: .warning
            ))
        }

        switch stats.thermalLevel {
        case .serious:
            alerts.append(ActiveAlert(
                id: "thermal",
                title: "Thermal pressure",
                message: "The system is throttling (serious thermal state)",
                severity: .warning
            ))
        case .critical:
            alerts.append(ActiveAlert(
                id: "thermal",
                title: "Thermal critical",
                message: "The system is critically hot — performance is reduced",
                severity: .critical
            ))
        case .nominal, .fair:
            break
        }

        deliverNotifications(for: alerts)
        return alerts
    }

    func requestAuthorization() {
        guard allowsNotifications, Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postTestNotification() {
        guard allowsNotifications else { return }
        requestAuthorization()
        post(
            title: "MacStats test alert",
            body: "Notifications work. Threshold alerts will show up here."
        )
    }

    // MARK: - Delivery (call with `lock` held)

    private func deliverNotifications(for alerts: [ActiveAlert]) {
        guard allowsNotifications, Bundle.main.bundleIdentifier != nil else { return }
        let now = Date()
        for alert in alerts {
            if let last = lastDelivered[alert.id], now.timeIntervalSince(last) < thresholds.cooldown {
                continue
            }
            lastDelivered[alert.id] = now
            post(title: alert.title, body: alert.message)
        }
    }

    private func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
