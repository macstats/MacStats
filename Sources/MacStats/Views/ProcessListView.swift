import SwiftUI
import AppKit

/// Process browser: sort by CPU/memory, filter by name or path, top 5/10/20,
/// and terminate misbehaving processes with a confirmation step.
///
/// Interaction state lives in `StatsViewModel` (this project builds without the
/// SwiftUI macro plugin, so `@State` is unavailable).
struct ProcessListView: View {
    @ObservedObject var viewModel: StatsViewModel

    private var processes: [TopProcess] { viewModel.topProcesses }

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 8) {
                header
                controls
                searchField

                if processes.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(processes.enumerated()), id: \.offset) { index, proc in
                        ProcessRow(rank: index + 1, process: proc)
                            .contextMenu {
                                Button("End Process") {
                                    confirmKill(proc, force: false)
                                }
                                Button("Force Kill") {
                                    confirmKill(proc, force: true)
                                }
                            }
                    }
                }

                if let message = viewModel.processActionMessage {
                    Text(message)
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "list.number")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.cyan)
            Text("Processes")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                viewModel.refreshProcesses()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Refresh process list")
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { viewModel.processSort },
                set: { viewModel.setProcessSort($0) }
            )) {
                ForEach(ProcessSortMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 118)

            Picker("", selection: Binding(
                get: { viewModel.processLimit },
                set: { viewModel.setProcessLimit($0) }
            )) {
                Text("5").tag(5)
                Text("10").tag(10)
                Text("20").tag(20)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 96)

            Spacer()

            Text("CPU")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 46, alignment: .trailing)
            Text("MEM")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            TextField("Filter by name or path", text: Binding(
                get: { viewModel.processSearch },
                set: { viewModel.updateProcessSearch($0) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11))

            if !viewModel.processSearch.isEmpty {
                Button {
                    viewModel.setProcessSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
        )
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Text(viewModel.processSearch.isEmpty ? "Loading…" : "No matching processes")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func confirmKill(_ process: TopProcess, force: Bool) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = force ? .critical : .warning
        alert.messageText = force ? "Force kill \(process.name)?" : "End \(process.name)?"
        alert.informativeText = "PID \(process.pid) will be \(force ? "killed immediately (SIGKILL)" : "asked to quit (SIGTERM)"). Unsaved work may be lost."
        alert.addButton(withTitle: force ? "Force Kill" : "End Process")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if !viewModel.kill(pid: process.pid, force: force) {
            viewModel.reportProcessError(
                "Could not \(force ? "kill" : "end") \(process.name) (PID \(process.pid)) — permission denied?"
            )
        }
    }
}

private struct ProcessRow: View {
    let rank: Int
    let process: TopProcess

    var body: some View {
        HStack(spacing: 6) {
            Text("\(rank)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(rankColor))

            Text(process.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .help(process.executablePath.isEmpty ? "\(process.name) (PID \(process.pid))" : process.executablePath)

            Spacer(minLength: 4)

            MiniBar(value: process.cpuPercent, max: 100, color: .blue)
                .frame(width: 18, height: 10)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(process.cpuPercent > 50 ? .orange : .secondary)
                .frame(width: 46, alignment: .trailing)

            Text(memoryText)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }

    private var memoryText: String {
        process.residentBytes > 0
            ? formatBytes(process.residentBytes)
            : String(format: "%.1f%%", process.memPercent)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .gray
        }
    }
}

private struct MiniBar: View {
    let value: Double
    let max: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(value / max, 1))
            }
        }
    }
}
