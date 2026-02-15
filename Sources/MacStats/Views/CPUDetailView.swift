import SwiftUI

struct CPUDetailView: View {
    let stats: CPUStats
    var history: [Double] = []

    private let coreColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 6)

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: ring + info
                HStack(spacing: 14) {
                    ZStack {
                        RingView(
                            progress: stats.totalUsage / 100.0,
                            lineWidth: 5,
                            colors: cpuGradient(stats.totalUsage)
                        )
                        Text(String(format: "%.0f", stats.totalUsage))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "cpu")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.blue)
                            Text("CPU")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("\(stats.coreCount) cores")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(String(format: "%.1f%%", stats.totalUsage))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }

                // Sparkline
                if history.count > 1 {
                    SparklineView(data: history, maxValue: 100, color: .blue)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.04))
                        )
                }

                // Per-core bars
                if !stats.perCoreUsage.isEmpty {
                    LazyVGrid(columns: coreColumns, spacing: 2) {
                        ForEach(Array(stats.perCoreUsage.enumerated()), id: \.offset) { _, usage in
                            CoreBar(usage: usage)
                        }
                    }
                }
            }
        }
    }

    private func cpuGradient(_ usage: Double) -> [Color] {
        if usage > 80 { return [.red, .orange] }
        if usage > 50 { return [.orange, .yellow] }
        return [.cyan, .blue]
    }
}

private struct CoreBar: View {
    let usage: Double

    private var color: Color {
        if usage > 80 { return .red }
        if usage > 50 { return .orange }
        return .cyan
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.quaternary)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(height: geo.size.height * min(usage / 100.0, 1.0))
            }
        }
        .frame(height: 20)
    }
}
