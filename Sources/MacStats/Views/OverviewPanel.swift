import SwiftUI

/// The signature surface: four at-a-glance tiles over one wide CPU trace.
/// Everything else in the popover is detail behind this summary.
struct OverviewPanel: View, Equatable {
    let cpu: CPUStats
    let memory: MemoryStats
    let disk: DiskStats
    let network: NetworkStats
    let cpuTrace: [Double]

    var body: some View {
        Panel {
            VStack(spacing: DS.Space.m) {
                HStack(alignment: .top, spacing: DS.Space.s) {
                    GaugeTile(
                        label: "CPU",
                        fraction: cpu.totalUsage / 100,
                        value: Format.percent(cpu.totalUsage),
                        color: DS.Palette.cpu
                    )
                    GaugeTile(
                        label: "Memory",
                        fraction: memory.usagePercent / 100,
                        value: Format.percent(memory.usagePercent),
                        color: DS.Palette.memory
                    )
                    GaugeTile(
                        label: "Disk",
                        fraction: disk.usagePercent / 100,
                        value: Format.percent(disk.usagePercent),
                        color: DS.Palette.disk
                    )
                    SpeedTile(network: network)
                }

                Rectangle()
                    .fill(DS.Palette.grid)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    HStack {
                        Text("CPU HISTORY")
                            .font(DS.Text.micro)
                            .foregroundColor(DS.Palette.tertiary)
                        Spacer()
                        Text("last \(cpuTrace.count) samples")
                            .font(DS.Text.micro)
                            .foregroundColor(DS.Palette.tertiary)
                    }
                    TraceView(
                        values: cpuTrace,
                        maxValue: 100,
                        color: DS.Palette.cpu,
                        gridLines: 3
                    )
                    .frame(height: 44)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Ring gauge + percentage + caption, sized for a four-across row.
private struct GaugeTile: View {
    let label: String
    let fraction: Double
    let value: String
    let color: Color

    private var status: StatusLevel { StatusLevel.usage(fraction) }

    private var gaugeColor: Color {
        status == .normal ? color : status.color
    }

    var body: some View {
        VStack(spacing: 5) {
            RingGauge(fraction: fraction, lineWidth: 4, color: gaugeColor) {
                Text(value)
                    .font(DS.Text.mono(11, weight: .semibold))
                    .foregroundColor(status == .normal ? DS.Palette.primary : status.color)
                    .monospacedDigit()
            }
            .frame(width: 40, height: 40)

            Text(label)
                .font(DS.Text.micro)
                .foregroundColor(DS.Palette.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// Network has no meaningful percentage, so it shows both directions.
private struct SpeedTile: View {
    let network: NetworkStats

    var body: some View {
        VStack(spacing: 5) {
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(DS.Palette.down)
                    Text(Format.menuBarSpeed(network.bytesReceivedPerSec))
                        .font(DS.Text.mono(10, weight: .semibold))
                        .foregroundColor(DS.Palette.primary)
                }
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(DS.Palette.up)
                    Text(Format.menuBarSpeed(network.bytesSentPerSec))
                        .font(DS.Text.mono(10, weight: .semibold))
                        .foregroundColor(DS.Palette.secondary)
                }
            }
            .frame(height: 40)

            Text("Network")
                .font(DS.Text.micro)
                .foregroundColor(DS.Palette.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Network, download \(Format.speed(network.bytesReceivedPerSec)), "
                + "upload \(Format.speed(network.bytesSentPerSec))"
        )
    }
}
