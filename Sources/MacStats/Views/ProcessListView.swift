import SwiftUI

struct ProcessListView: View, Equatable {
    let processes: [TopProcess]
    @Binding var sort: ProcessSortKey

    static func == (lhs: ProcessListView, rhs: ProcessListView) -> Bool {
        lhs.processes == rhs.processes && lhs.sort == rhs.sort
    }

    private var ranked: [TopProcess] {
        processes.sorted { lhs, rhs in
            switch sort {
            case .cpu:
                return lhs.cpuPercent == rhs.cpuPercent
                    ? lhs.memPercent > rhs.memPercent
                    : lhs.cpuPercent > rhs.cpuPercent
            case .memory:
                return lhs.memPercent == rhs.memPercent
                    ? lhs.cpuPercent > rhs.cpuPercent
                    : lhs.memPercent > rhs.memPercent
            }
        }
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                PanelHeader("Top Processes", symbol: "list.number") {
                    Picker("Sort", selection: $sort) {
                        ForEach(ProcessSortKey.allCases, id: \.self) { key in
                            Text(key.label).tag(key)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.mini)
                    .labelsHidden()
                    .frame(width: 108)
                    .accessibilityLabel("Sort processes")
                }

                HStack(spacing: 6) {
                    Text("PROCESS")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU")
                        .frame(width: 46, alignment: .trailing)
                    Text("MEM")
                        .frame(width: 42, alignment: .trailing)
                }
                .font(DS.Text.micro)
                .foregroundColor(DS.Palette.tertiary)

                if processes.isEmpty {
                    HStack(spacing: DS.Space.s) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Sampling…")
                            .font(DS.Text.body)
                            .foregroundColor(DS.Palette.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Space.s)
                } else {
                    VStack(spacing: 1) {
                        ForEach(Array(ranked.enumerated()), id: \.element.id) { index, process in
                            ProcessRow(rank: index + 1, process: process, sort: sort)
                        }
                    }
                }
            }
        }
    }
}

private struct ProcessRow: View {
    let rank: Int
    let process: TopProcess
    let sort: ProcessSortKey

    private var cpuLevel: StatusLevel { StatusLevel.usage(process.cpuPercent / 100, elevated: 0.5, critical: 0.8) }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(rank)")
                .font(DS.Text.mono(9))
                .foregroundColor(DS.Palette.tertiary)
                .frame(width: 12, alignment: .leading)

            Text(process.name)
                .font(.system(size: 11, weight: sort == .cpu || sort == .memory ? .medium : .regular))
                .foregroundColor(DS.Palette.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(DS.Text.mono(10))
                .foregroundColor(cpuLevel == .normal ? DS.Palette.secondary : cpuLevel.color)
                .monospacedDigit()
                .frame(width: 46, alignment: .trailing)

            Text(String(format: "%.1f%%", process.memPercent))
                .font(DS.Text.mono(10))
                .foregroundColor(DS.Palette.secondary)
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
        .frame(height: DS.Layout.rowHeight)
        .modifier(HoverHighlight())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(process.name), CPU \(String(format: "%.1f", process.cpuPercent)) percent, "
                + "memory \(String(format: "%.1f", process.memPercent)) percent"
        )
    }
}
