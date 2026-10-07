import SwiftUI

/// Process browser: ranked list with filtering, row-count control and
/// SIGTERM/SIGKILL actions. Ranking happens in `ProcessMonitor` so the UI
/// never sorts on the main thread.
struct ProcessListView: View {
    @ObservedObject var viewModel: StatsViewModel
    @Binding var sort: ProcessSortKey

    @State private var query = ""
    @State private var searchDebounce: Task<Void, Never>?

    private static let limits = [5, 10, 20]

    private var processes: [TopProcess] { viewModel.processes }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                PanelHeader("Processes", symbol: "list.number") {
                    HStack(spacing: DS.Space.s) {
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

                        Menu {
                            ForEach(Self.limits, id: \.self) { value in
                                Button("Top \(value)") {
                                    viewModel.setProcessLimit(value)
                                }
                            }
                        } label: {
                            Text("\(viewModel.processLimit)")
                                .font(DS.Text.mono(10, weight: .medium))
                                .foregroundColor(DS.Palette.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 20)
                        .accessibilityLabel("Rows to show")
                    }
                }

                searchField

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
                    emptyState
                } else {
                    VStack(spacing: 1) {
                        ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                            ProcessRow(rank: index + 1, process: process, sort: sort)
                                .contextMenu {
                                    Button("Quit “\(process.name)”") {
                                        viewModel.kill(pid: process.pid, force: false)
                                    }
                                    Button("Force Quit “\(process.name)”") {
                                        viewModel.kill(pid: process.pid, force: true)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.setProcessSort(sort)
        }
        .onChange(of: sort) { newValue in
            viewModel.setProcessSort(newValue)
        }
        .onDisappear {
            searchDebounce?.cancel()
        }
    }

    private var searchField: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(DS.Palette.tertiary)

            TextField("Filter by name or path", text: $query)
                .textFieldStyle(.plain)
                .font(DS.Text.body)
                .onChange(of: query) { newValue in
                    scheduleSearch(newValue)
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    scheduleSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(DS.Palette.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear filter")
            }
        }
        .padding(.horizontal, DS.Space.s)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                .fill(DS.Palette.inset)
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        HStack(spacing: DS.Space.s) {
            if query.isEmpty {
                ProgressView()
                    .controlSize(.small)
                Text("Sampling…")
                    .font(DS.Text.body)
                    .foregroundColor(DS.Palette.secondary)
            } else {
                Text("No processes match “\(query)”")
                    .font(DS.Text.body)
                    .foregroundColor(DS.Palette.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.s)
    }

    /// Typing should not run a full `proc_pidinfo` sweep on every keystroke.
    private func scheduleSearch(_ text: String) {
        searchDebounce?.cancel()
        searchDebounce = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            viewModel.setProcessSearch(text)
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
