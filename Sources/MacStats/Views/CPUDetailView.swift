import SwiftUI

struct CPUDetailView: View, Equatable {
    let stats: CPUStats
    let trace: [Double]

    private var status: StatusLevel { StatusLevel.usage(stats.totalUsage / 100) }

    private var valueColor: Color {
        status == .normal ? DS.Palette.primary : status.color
    }

    /// Cores are laid out as one equalizer row when they fit; very wide CPUs
    /// wrap to an 8-column grid instead of squeezing into slivers.
    private var columns: [GridItem] {
        let count = stats.coreCount
        guard count > 0 else { return [] }
        let used = count <= 10 ? count : 8
        return Array(repeating: GridItem(.flexible(), spacing: 3), count: used)
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.m) {
                PanelHeader("CPU", symbol: "cpu") {
                    Text("\(stats.coreCount) cores")
                        .font(DS.Text.label)
                        .foregroundColor(DS.Palette.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                    Text(Format.percent(stats.totalUsage, decimals: 1))
                        .font(DS.Text.metric)
                        .foregroundColor(valueColor)
                        .monospacedDigit()

                    Spacer(minLength: DS.Space.s)

                    if let busiest = stats.busiestCore {
                        Text("busiest core \(busiest.index + 1) · \(Format.percent(busiest.usage))")
                            .font(DS.Text.micro)
                            .foregroundColor(DS.Palette.secondary)
                    }
                }

                if !stats.perCoreUsage.isEmpty {
                    LazyVGrid(columns: columns, spacing: 3) {
                        ForEach(Array(stats.perCoreUsage.enumerated()), id: \.offset) { _, usage in
                            CoreBar(usage: usage)
                        }
                    }
                }

                if stats.load.one > 0 || stats.load.fifteen > 0 {
                    HStack(spacing: DS.Space.l) {
                        LoadValue(label: "1 min", value: stats.load.one)
                        LoadValue(label: "5 min", value: stats.load.five)
                        LoadValue(label: "15 min", value: stats.load.fifteen)
                    }
                }
            }
        }
    }
}

private struct LoadValue: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(DS.Text.micro)
                .foregroundColor(DS.Palette.tertiary)
            Text(String(format: "%.2f", value))
                .font(DS.Text.mono(10, weight: .medium))
                .foregroundColor(DS.Palette.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Load average \(label): \(String(format: "%.2f", value))")
    }
}
