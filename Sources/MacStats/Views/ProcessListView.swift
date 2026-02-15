import SwiftUI

struct ProcessListView: View {
    let processes: [TopProcess]

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "list.number")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan)
                    Text("Top Processes")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("CPU")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 42, alignment: .trailing)
                    Text("MEM")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }

                if processes.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(Array(processes.enumerated()), id: \.offset) { index, proc in
                        ProcessRow(rank: index + 1, process: proc)
                    }
                }
            }
        }
    }
}

private struct ProcessRow: View {
    let rank: Int
    let process: TopProcess

    var body: some View {
        HStack(spacing: 6) {
            // Rank badge
            Text("\(rank)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(
                    Circle().fill(rankColor)
                )

            // Process name
            Text(process.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // CPU bar + value
            MiniBar(value: process.cpuPercent, max: 100, color: .blue)
                .frame(width: 20, height: 10)
            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(process.cpuPercent > 50 ? .orange : .secondary)
                .frame(width: 42, alignment: .trailing)

            // MEM value
            Text(String(format: "%.1f%%", process.memPercent))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.vertical, 1)
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
