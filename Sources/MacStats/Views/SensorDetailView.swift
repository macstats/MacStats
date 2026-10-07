import SwiftUI

/// Thermal / fan card fed by `SensorMonitor` (AppleSMC).
struct SensorDetailView: View {
    let stats: SensorStats

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.pink)
                    Text("Thermals")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if !stats.temperatureKey.isEmpty {
                        Text(stats.temperatureKey)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.quaternary))
                    }
                }

                if let temperature = stats.cpuTemperature {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(String(format: "%.1f", temperature))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(temperatureColor)
                        Text("°C")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: temperatureIcon)
                            .font(.system(size: 13))
                            .foregroundColor(temperatureColor)
                    }

                    UsageBarView(
                        value: temperature,
                        maxValue: 110,
                        color: temperatureColor
                    )
                }

                if !stats.fans.isEmpty {
                    Divider()
                    ForEach(stats.fans) { fan in
                        HStack(spacing: 6) {
                            Image(systemName: "fanblades")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text("Fan \(fan.index)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            if fan.maxRPM > 0 {
                                Text("\(fan.minRPM)–\(fan.maxRPM)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(fan.rpm) RPM")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var temperatureColor: Color {
        guard let temperature = stats.cpuTemperature else { return .secondary }
        if temperature >= 80 { return .red }
        if temperature >= 65 { return .orange }
        return .green
    }

    private var temperatureIcon: String {
        guard let temperature = stats.cpuTemperature else { return "thermometer" }
        if temperature >= 80 { return "flame.fill" }
        if temperature >= 65 { return "thermometer.high" }
        return "thermometer.low"
    }
}
