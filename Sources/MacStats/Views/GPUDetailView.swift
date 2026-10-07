import SwiftUI

/// GPU utilization / memory card, fed by `GPUMonitor` (IOAccelerator).
struct GPUDetailView: View, Equatable {
    let stats: GPUStats
    var history: [Double] = []

    /// Utilization always reads against a 0–100% axis so the trace does not
    /// rescale itself into noise.
    private var traceScale: Double { 100 }

    private var status: StatusLevel {
        StatusLevel.usage(stats.utilizationPercent / 100, elevated: 0.7, critical: 0.9)
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                PanelHeader("GPU", symbol: "cpu") {
                    Text(stats.name.isEmpty ? "Graphics" : stats.name)
                        .font(DS.Text.label)
                        .foregroundColor(DS.Palette.secondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                    Text(Format.percent(stats.utilizationPercent, decimals: 1))
                        .font(DS.Text.metric)
                        .foregroundColor(status == .normal ? DS.Palette.primary : status.color)
                        .monospacedDigit()

                    Spacer(minLength: DS.Space.s)

                    if stats.memoryTotalBytes > 0 {
                        Text("\(Format.bytes(stats.memoryUsedBytes)) / \(Format.bytes(stats.memoryTotalBytes))")
                            .font(DS.Text.label)
                            .foregroundColor(DS.Palette.secondary)
                            .monospacedDigit()
                    }
                }

                TraceView(
                    values: history,
                    maxValue: traceScale,
                    color: DS.Palette.cpu,
                    showsFill: false,
                    gridLines: 1
                )
                .frame(height: 22)

                HStack(spacing: DS.Space.l) {
                    GPUValue(label: "Memory", value: Format.percent(stats.memoryUsagePercent, decimals: 0))
                    GPUValue(
                        label: "Cores",
                        value: stats.coreCount > 0 ? "\(stats.coreCount)" : "—"
                    )
                }
            }
        }
    }
}

private struct GPUValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(DS.Text.micro)
                .foregroundColor(DS.Palette.tertiary)
            Text(value)
                .font(DS.Text.mono(10, weight: .medium))
                .foregroundColor(DS.Palette.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
