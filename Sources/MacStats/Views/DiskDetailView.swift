import SwiftUI

struct DiskDetailView: View, Equatable {
    let stats: DiskStats

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
            }
        }
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
