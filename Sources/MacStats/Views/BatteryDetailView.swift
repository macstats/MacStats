import SwiftUI

struct BatteryDetailView: View, Equatable {
    let stats: BatteryStats

    private var chargeLevel: StatusLevel {
        if stats.chargePercent <= 10 { return .critical }
        if stats.chargePercent <= 20 { return .elevated }
        return .normal
    }

    private var chargeColor: Color {
        stats.isCharging ? DS.Palette.ok : (chargeLevel == .normal ? DS.Palette.memory : chargeLevel.color)
    }

    private var statusText: String {
        if stats.isCharging { return "Charging" }
        if stats.isPluggedIn { return "Plugged In" }
        return "On Battery"
    }

    private var statusSymbol: String {
        if stats.isCharging { return "bolt.fill" }
        if stats.isPluggedIn { return "powerplug.fill" }
        return "battery.50"
    }

    private var remainingText: String {
        if stats.isCharging, stats.timeToFull > 0 { return "\(Format.minutes(stats.timeToFull)) to full" }
        if !stats.isCharging, stats.timeToEmpty > 0 { return "\(Format.minutes(stats.timeToEmpty)) left" }
        return chargeLevel == .normal ? "—" : "Low"
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                PanelHeader("Battery", symbol: "battery.100") {
                    StatusChip(
                        text: statusText,
                        symbol: statusSymbol,
                        level: stats.isCharging || stats.isPluggedIn ? .normal : chargeLevel
                    )
                }

                HStack(spacing: DS.Space.m) {
                    RingGauge(fraction: stats.chargePercent / 100, lineWidth: 5, color: chargeColor) {
                        Text(Format.percent(stats.chargePercent))
                            .font(DS.Text.mono(11, weight: .semibold))
                            .foregroundColor(DS.Palette.primary)
                            .monospacedDigit()
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(remainingText)
                            .font(DS.Text.readout)
                            .foregroundColor(DS.Palette.primary)
                        Text("\(stats.cycleCount) cycles")
                            .font(DS.Text.micro)
                            .foregroundColor(DS.Palette.secondary)
                    }

                    Spacer(minLength: DS.Space.s)
                }

                VStack(spacing: 2) {
                    if stats.healthPercent > 0 {
                        StatRowView(
                            label: "Health",
                            value: String(format: "%.1f%%", stats.healthPercent),
                            icon: "heart.fill",
                            iconColor: healthLevel.color,
                            valueColor: healthLevel == .normal ? DS.Palette.primary : healthLevel.color
                        )
                    }
                    if stats.temperature > 0 {
                        StatRowView(
                            label: "Temperature",
                            value: String(format: "%.1f °C", stats.temperature),
                            icon: "thermometer.medium",
                            iconColor: temperatureLevel.color
                        )
                    }
                    if stats.designCapacity > 0 {
                        StatRowView(
                            label: "Design Capacity",
                            value: "\(stats.designCapacity) mAh",
                            icon: "battery.100",
                            iconColor: DS.Palette.tertiary
                        )
                    }
                }
            }
        }
    }

    private var healthLevel: StatusLevel {
        if stats.healthPercent >= 80 { return .normal }
        if stats.healthPercent >= 60 { return .elevated }
        return .critical
    }

    private var temperatureLevel: StatusLevel {
        if stats.temperature >= 40 { return .critical }
        if stats.temperature >= 35 { return .elevated }
        return .normal
    }
}
