import SwiftUI

struct DiskDetailView: View {
    let stats: DiskStats
    var readHistory: [Double] = []
    var writeHistory: [Double] = []

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    ZStack {
                        RingView(
                            progress: stats.usagePercent / 100.0,
                            lineWidth: 5,
                            colors: diskGradient(stats.usagePercent)
                        )
                        Image(systemName: "internaldrive")
                            .font(.system(size: 13))
                            .foregroundColor(.orange)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text("Disk")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("Macintosh HD")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(String(format: "%.1f%%", stats.usagePercent))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }

                UsageBarView(
                    value: Double(stats.usedBytes),
                    maxValue: Double(stats.totalBytes),
                    color: stats.usagePercent > 85 ? .red : .orange
                )

                HStack {
                    DiskStat(label: "Used", value: formatBytes(stats.usedBytes))
                    Spacer()
                    DiskStat(label: "Free", value: formatBytes(stats.freeBytes))
                    Spacer()
                    DiskStat(label: "Total", value: formatBytes(stats.totalBytes))
                }

                // Baseline I/O row — the disk-I/O feature agent owns the final layout.
                Divider()
                HStack(spacing: 8) {
                    DiskIOStat(
                        label: "Read",
                        symbol: "arrow.down.circle",
                        color: .green,
                        speed: stats.readBytesPerSec,
                        history: readHistory
                    )
                    DiskIOStat(
                        label: "Write",
                        symbol: "arrow.up.circle",
                        color: .orange,
                        speed: stats.writeBytesPerSec,
                        history: writeHistory
                    )
                }
            }
        }
    }

    private func diskGradient(_ pct: Double) -> [Color] {
        if pct > 90 { return [.red, .pink] }
        if pct > 75 { return [.orange, .yellow] }
        return [.orange, .yellow]
    }
}

private struct DiskIOStat: View {
    let label: String
    let symbol: String
    let color: Color
    let speed: Double
    let history: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text(diskIOSpeed(speed))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            if history.count > 1 {
                SparklineView(data: history, maxValue: max(history.max() ?? 1, 1), color: color)
                    .frame(height: 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DiskStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
    }
}

private func diskIOSpeed(_ bps: Double) -> String {
    if bps < 1024 {
        return String(format: "%.0f B/s", bps)
    } else if bps < 1024 * 1024 {
        return String(format: "%.1f KB/s", bps / 1024)
    } else if bps < 1024 * 1024 * 1024 {
        return String(format: "%.1f MB/s", bps / (1024 * 1024))
    } else {
        return String(format: "%.2f GB/s", bps / (1024 * 1024 * 1024))
    }
}
