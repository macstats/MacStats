import SwiftUI

struct MemoryDetailView: View, Equatable {
    let stats: MemoryStats

    private var status: StatusLevel {
        let usage = StatusLevel.usage(stats.usagePercent / 100)
        return Swift.max(usage, stats.pressure.level)
    }

    private var valueColor: Color {
        status == .normal ? DS.Palette.primary : status.color
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                PanelHeader("Memory", symbol: "memorychip") {
                    if stats.pressure != .normal {
                        StatusChip(
                            text: "\(stats.pressure.label) pressure",
                            symbol: "exclamationmark.triangle.fill",
                            level: stats.pressure.level
                        )
                    } else {
                        Text(Format.bytes(stats.totalBytes))
                            .font(DS.Text.label)
                            .foregroundColor(DS.Palette.secondary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                    Text(Format.percent(stats.usagePercent, decimals: 1))
                        .font(DS.Text.metric)
                        .foregroundColor(valueColor)
                        .monospacedDigit()

                    Spacer(minLength: DS.Space.s)

                    Text("\(Format.bytes(stats.usedBytes)) of \(Format.bytes(stats.totalBytes))")
                        .font(DS.Text.label)
                        .foregroundColor(DS.Palette.secondary)
                }

                SegmentedBar(
                    segments: [
                        .init(value: Double(stats.activeBytes), color: DS.Palette.memory, label: "Active"),
                        .init(value: Double(stats.wiredBytes), color: DS.Palette.memory.opacity(0.72), label: "Wired"),
                        .init(value: Double(stats.compressedBytes), color: DS.Palette.memory.opacity(0.45), label: "Compressed"),
                        .init(value: Double(stats.freeBytes), color: DS.Palette.track, label: "Free"),
                    ],
                    total: Double(stats.totalBytes)
                )

                HStack(spacing: DS.Space.s) {
                    LegendDot(color: DS.Palette.memory, label: "Active", value: Format.compactBytes(stats.activeBytes))
                    LegendDot(color: DS.Palette.memory.opacity(0.72), label: "Wired", value: Format.compactBytes(stats.wiredBytes))
                    LegendDot(color: DS.Palette.memory.opacity(0.45), label: "Compr.", value: Format.compactBytes(stats.compressedBytes))
                    LegendDot(color: DS.Palette.track, label: "Free", value: Format.compactBytes(stats.freeBytes))
                }
            }
        }
    }
}
