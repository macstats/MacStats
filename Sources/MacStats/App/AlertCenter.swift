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
/// `evaluate(_:)` runs on the monitor queue on every tick, so it stays cheap
/// and allocation-light. Notifications are rate-limited per condition with a
/// cooldown, and both notification entry points no-op when the process is not
/// running from an app bundle (UserNotifications requires a bundle id).
final class AlertCenter {
    private let enabledKey = "MacStats.alertsEnabled"
    private let defaults: UserDefaults
    private let postsNotifications: Bool
    private let cooldown: TimeInterval = 15 * 60
    /// Confined to the monitor queue.
    private var lastNotified: [String: Date] = [:]

    init(postsNotifications: Bool = true, defaults: UserDefaults = .standard) {
        self.postsNotifications = postsNotifications
        self.defaults = defaults
        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(true, forKey: enabledKey)
        }
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    /// Returns the set of alerts that are active right now.
    func evaluate(_ stats: SystemStats) -> [ActiveAlert] {
        guard isEnabled else { return [] }

        var alerts: [ActiveAlert] = []

        switch stats.memory.pressure {
        case .critical:
            alerts.append(
                ActiveAlert(
                    id: "memory-pressure",
                    title: "Memory pressure critical",
                    message: "macOS reports critical memory pressure — close heavy apps or add memory.",
                    severity: .critical
                )
            )
        case .warning:
            alerts.append(
                ActiveAlert(
                    id: "memory-pressure",
                    title: "Memory pressure warning",
                    message: "macOS reports elevated memory pressure.",
                    severity: .warning
                )
            )
        case .normal:
            break
        }

        if stats.cpu.totalUsage >= 90 {
            alerts.append(
                ActiveAlert(
                    id: "cpu-usage",
                    title: "CPU near saturation",
                    message: String(format: "CPU has been at %.0f%%.", stats.cpu.totalUsage),
                    severity: .warning
                )
            )
        }

        if stats.memory.usagePercent >= 92 {
            alerts.append(
                ActiveAlert(
                    id: "memory-usage",
                    title: "Memory almost full",
                    message: String(format: "%.0f%% of physical memory is in use.", stats.memory.usagePercent),
                    severity: .warning
                )
            )
        }

        if stats.disk.usagePercent >= 90 {
            alerts.append(
                ActiveAlert(
                    id: "disk-usage",
                    title: "Startup disk almost full",
                    message: String(format: "%@ is %.0f%% full.", stats.disk.volumeName, stats.disk.usagePercent),
                    severity: .warning
                )
            )
        }

        switch stats.thermalLevel {
        case .critical:
            alerts.append(
                ActiveAlert(
                    id: "thermal",
                    title: "Thermal state critical",
                    message: "The system is thermally throttled; performance is reduced.",
                    severity: .critical
                )
            )
        case .serious:
            alerts.append(
                ActiveAlert(
                    id: "thermal",
                    title: "Thermal state serious",
                    message: "The system is running hot and may throttle.",
                    severity: .warning
                )
            )
        default:
            break
        }

        if let temperature = stats.sensors.cpuTemperature, temperature >= 95 {
            alerts.append(
                ActiveAlert(
                    id: "temperature",
                    title: "CPU temperature high",
                    message: String(format: "CPU is at %.0f°C.", temperature),
                    severity: .critical
                )
            )
        }

        if stats.battery.isPresent, !stats.battery.isPluggedIn {
            let charge = stats.battery.chargePercent
            if charge <= 10 {
                alerts.append(
                    ActiveAlert(
                        id: "battery",
                        title: "Battery critically low",
                        message: String(format: "%.0f%% remaining — plug in now.", charge),
                        severity: .critical
                    )
                )
            } else if charge <= 20 {
                alerts.append(
                    ActiveAlert(
                        id: "battery",
                        title: "Battery low",
                        message: String(format: "%.0f%% remaining.", charge),
                        severity: .warning
                    )
                )
            }
        }

        deliverNotifications(for: alerts)
        return alerts
    }

    func requestAuthorization() {
        guard postsNotifications, Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postTestNotification() {
        post(
            ActiveAlert(
                id: "test",
                title: "MacStats alerts are on",
                message: "Threshold notifications will look like this.",
                severity: .warning
            )
        )
    }

    // MARK: - Private

    private func deliverNotifications(for alerts: [ActiveAlert]) {
        guard postsNotifications else { return }
        let now = Date()
        for alert in alerts {
            if let last = lastNotified[alert.id], now.timeIntervalSince(last) < cooldown {
                continue
            }
            lastNotified[alert.id] = now
            post(alert)
        }
        // Forget conditions that have cleared so they can notify again later.
        let active = Set(alerts.map(\.id))
        lastNotified = lastNotified.filter { active.contains($0.key) }
    }

    private func post(_ alert: ActiveAlert) {
        guard postsNotifications, Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message
        if #available(macOS 12.0, *) {
            content.sound = alert.severity == .critical ? .defaultCritical : .default
        } else {
            content.sound = .default
        }
        let request = UNNotificationRequest(
            identifier: "MacStats.\(alert.id).\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
