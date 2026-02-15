import SwiftUI

struct BatteryDetailView: View {
    let stats: BatteryStats

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 10) {
                // Header row: ring + title + percentage
                HStack(spacing: 14) {
                    ZStack {
                        RingView(
                            progress: stats.chargePercent / 100.0,
                            lineWidth: 5,
                            colors: batteryGradient(stats.chargePercent)
                        )
                        Image(systemName: batteryIcon)
                            .font(.system(size: 13))
                            .foregroundColor(batteryIconColor)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text("Battery")
                                .font(.system(size: 13, weight: .semibold))
                            if stats.isCharging {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                            } else if stats.isPluggedIn {
                                Image(systemName: "powerplug.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                            }
                        }
                        Text(statusText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(String(format: "%.0f%%", stats.chargePercent))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }

                // Detail rows
                VStack(spacing: 4) {
                    if stats.isCharging && stats.timeToFull > 0 {
                        StatRowView(
                            label: "Time to Full",
                            value: formatMinutes(stats.timeToFull),
                            icon: "clock",
                            iconColor: .green
                        )
                    } else if !stats.isCharging && stats.timeToEmpty > 0 {
                        StatRowView(
                            label: "Time Remaining",
                            value: formatMinutes(stats.timeToEmpty),
                            icon: "clock",
                            iconColor: .orange
                        )
                    }

                    StatRowView(
                        label: "Cycle Count",
                        value: "\(stats.cycleCount)",
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .blue
                    )

                    if stats.healthPercent > 0 {
                        StatRowView(
                            label: "Health",
                            value: String(format: "%.1f%%", stats.healthPercent),
                            icon: "heart.fill",
                            iconColor: healthColor
                        )
                    }

                    if stats.temperature > 0 {
                        StatRowView(
                            label: "Temperature",
                            value: String(format: "%.1f°C", stats.temperature),
                            icon: "thermometer.medium",
                            iconColor: tempColor
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var batteryIcon: String {
        let pct = stats.chargePercent
        if stats.isCharging { return "battery.100.bolt" }
        if pct > 75 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryIconColor: Color {
        if stats.isCharging { return .green }
        if stats.chargePercent <= 20 { return .red }
        return .green
    }

    private var statusText: String {
        if stats.isCharging { return "Charging" }
        if stats.isPluggedIn { return "Plugged In" }
        return "On Battery"
    }

    private var healthColor: Color {
        if stats.healthPercent >= 80 { return .green }
        if stats.healthPercent >= 50 { return .orange }
        return .red
    }

    private var tempColor: Color {
        if stats.temperature >= 40 { return .red }
        if stats.temperature >= 35 { return .orange }
        return .blue
    }

    private func batteryGradient(_ pct: Double) -> [Color] {
        if pct <= 20 { return [.red, .orange] }
        if pct <= 50 { return [.orange, .yellow] }
        return [.green, .mint]
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }
}
