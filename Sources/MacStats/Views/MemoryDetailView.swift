import SwiftUI

struct MemoryDetailView: View {
    let stats: MemoryStats

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: ring + info
                HStack(spacing: 14) {
                    ZStack {
                        RingView(
                            progress: stats.usagePercent / 100.0,
                            lineWidth: 5,
                            colors: memGradient(stats.usagePercent)
                        )
                        Text(String(format: "%.0f", stats.usagePercent))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "memorychip")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.green)
                            Text("Memory")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("\(formatBytes(stats.usedBytes)) / \(formatBytes(stats.totalBytes))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(String(format: "%.1f%%", stats.usagePercent))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }

                // Segmented bar
                SegmentedBarView(
                    segments: [
                        (value: Double(stats.activeBytes), color: .green, label: "Active"),
                        (value: Double(stats.wiredBytes), color: .yellow, label: "Wired"),
                        (value: Double(stats.compressedBytes), color: .orange, label: "Compressed"),
                    ],
                    total: Double(stats.totalBytes),
                    height: 6
                )

                // Legend + details
                HStack(spacing: 0) {
                    MemBlock(color: .green, label: "Active", value: formatBytes(stats.activeBytes))
                    MemBlock(color: .yellow, label: "Wired", value: formatBytes(stats.wiredBytes))
                    MemBlock(color: .orange, label: "Compr.", value: formatBytes(stats.compressedBytes))
                    MemBlock(color: Color(nsColor: .separatorColor), label: "Free", value: formatBytes(stats.freeBytes))
                }
            }
        }
    }

    private func memGradient(_ pct: Double) -> [Color] {
        if pct > 85 { return [.red, .orange] }
        if pct > 65 { return [.yellow, .green] }
        return [.mint, .green]
    }
}

private struct MemBlock: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}

func formatBytes(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / (1024 * 1024 * 1024)
    if gb >= 1.0 { return String(format: "%.1fG", gb) }
    let mb = Double(bytes) / (1024 * 1024)
    return String(format: "%.0fM", mb)
}
