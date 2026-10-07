import SwiftUI

struct DiskDetailView: View, Equatable {
    let stats: DiskStats
    var readTrace: [Double] = []
    var writeTrace: [Double] = []

    private var status: StatusLevel { StatusLevel.usage(stats.usagePercent / 100, elevated: 0.8, critical: 0.92) }

    private var barColor: Color {
        status == .normal ? DS.Palette.disk : status.color
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                PanelHeader("Disk", symbol: "internaldrive") {
                    Text(stats.volumeName)
                        .font(DS.Text.label)
                        .foregroundColor(DS.Palette.secondary)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                    Text(Format.percent(stats.usagePercent, decimals: 1))
                        .font(DS.Text.metric)
                        .foregroundColor(status == .normal ? DS.Palette.primary : status.color)
                        .monospacedDigit()

                    Spacer(minLength: DS.Space.s)

                    Text("\(Format.bytes(stats.freeBytes)) free")
                        .font(DS.Text.label)
                        .foregroundColor(DS.Palette.secondary)
                }

                ProgressBar(fraction: stats.usagePercent / 100, color: barColor)

                HStack(spacing: DS.Space.l) {
                    DiskValue(label: "Used", value: Format.bytes(stats.usedBytes))
                    DiskValue(label: "Free", value: Format.bytes(stats.freeBytes))
                    DiskValue(label: "Total", value: Format.bytes(stats.totalBytes))
                }

                HStack(spacing: DS.Space.l) {
                    ThroughputReadout(
                        label: "Read",
                        symbol: "arrow.down",
                        color: DS.Palette.down,
                        speed: stats.readBytesPerSec,
                        trace: readTrace
                    )
                    ThroughputReadout(
                        label: "Write",
                        symbol: "arrow.up",
                        color: DS.Palette.up,
                        speed: stats.writeBytesPerSec,
                        trace: writeTrace
                    )
                }
            }
        }
    }
}

/// Live device throughput: label, rate and a compact trace, shared by the
/// read and write halves of the disk panel.
private struct ThroughputReadout: View {
    let label: String
    let symbol: String
    let color: Color
    let speed: Double
    let trace: [Double]

    private var scale: Double {
        Swift.max(trace.max() ?? 0, 1) * 1.1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(DS.Text.micro)
                    .foregroundColor(DS.Palette.secondary)
                Spacer(minLength: DS.Space.xs)
                Text(Format.speed(speed))
                    .font(DS.Text.mono(10, weight: .medium))
                    .foregroundColor(DS.Palette.primary)
                    .monospacedDigit()
            }

            TraceView(values: trace, maxValue: scale, color: color, showsFill: false, gridLines: 0)
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Disk \(label) \(Format.speed(speed))")
    }
}

private struct DiskValue: View {
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
