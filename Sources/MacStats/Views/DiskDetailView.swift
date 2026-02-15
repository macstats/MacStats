import SwiftUI

struct DiskDetailView: View {
    let stats: DiskStats

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
            }
        }
    }

    private func diskGradient(_ pct: Double) -> [Color] {
        if pct > 90 { return [.red, .pink] }
        if pct > 75 { return [.orange, .yellow] }
        return [.orange, .yellow]
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
