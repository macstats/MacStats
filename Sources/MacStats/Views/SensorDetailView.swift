import SwiftUI

/// Thermal / fan card fed by `SensorMonitor` (SMC).
///
/// Rows whose data is missing are hidden instead of rendering placeholders.
struct SensorDetailView: View, Equatable {
    let stats: SensorStats

    private var temperatureStatus: StatusLevel? {
        guard let temperature = stats.cpuTemperature else { return nil }
        if temperature >= 90 { return .critical }
        if temperature >= 75 { return .elevated }
        return .normal
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                PanelHeader("Thermals", symbol: "thermometer.medium") {
                    if !stats.temperatureKey.isEmpty {
                        Text(stats.temperatureKey)
                            .font(DS.Text.mono(9))
                            .foregroundColor(DS.Palette.tertiary)
                    }
                }

                if let temperature = stats.cpuTemperature {
                    HStack(spacing: DS.Space.s) {
                        Text("CPU")
                            .font(DS.Text.body)
                            .foregroundColor(DS.Palette.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.1f °C", temperature))
                            .font(DS.Text.mono(11, weight: .medium))
                            .foregroundColor(temperatureStatus == .normal ? DS.Palette.primary : temperatureStatus?.color ?? DS.Palette.primary)
                            .monospacedDigit()
                    }
                    .frame(height: DS.Layout.rowHeight)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("CPU temperature \(String(format: "%.1f", temperature)) degrees Celsius")
                }

                ForEach(stats.fans) { fan in
                    HStack(spacing: DS.Space.s) {
                        Text("Fan \(fan.index)")
                            .font(DS.Text.body)
                            .foregroundColor(DS.Palette.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(fan.rpm) RPM")
                            .font(DS.Text.mono(11, weight: .medium))
                            .foregroundColor(DS.Palette.primary)
                            .monospacedDigit()
                        if fan.maxRPM > 0 {
                            Text("of \(fan.maxRPM)")
                                .font(DS.Text.micro)
                                .foregroundColor(DS.Palette.tertiary)
                        }
                    }
                    .frame(height: DS.Layout.rowHeight)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Fan \(fan.index) at \(fan.rpm) RPM")
                }
            }
        }
    }
}
