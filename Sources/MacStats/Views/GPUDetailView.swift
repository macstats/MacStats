import SwiftUI

/// GPU utilization / memory card, fed by `GPUMonitor`.
struct GPUDetailView: View {
    let stats: GPUStats
    var history: [Double] = []

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        RingView(
                            progress: stats.utilizationPercent / 100.0,
                            lineWidth: 5,
                            colors: gpuGradient
                        )
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 13))
                            .foregroundColor(.purple)
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text("GPU")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer()

                    Text(String(format: "%.1f%%", stats.utilizationPercent))
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }

                if history.count > 1 {
                    SparklineView(data: history, maxValue: 100, color: .purple)
                        .frame(height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.purple.opacity(0.04))
                        )
                }

                if stats.memoryUsedBytes > 0 {
                    VStack(alignment: .leading, spacing: 5) {
                        if stats.memoryTotalBytes > 0 {
                            UsageBarView(
                                value: Double(stats.memoryUsedBytes),
                                maxValue: Double(stats.memoryTotalBytes),
                                color: .purple
                            )
                            HStack {
                                Text("Memory")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(formatBytes(stats.memoryUsedBytes)) / \(formatBytes(stats.memoryTotalBytes))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .monospacedDigit()
                            }
                        } else {
                            StatRowView(
                                label: "Memory in use",
                                value: formatBytes(stats.memoryUsedBytes),
                                icon: "memorychip",
                                iconColor: .purple
                            )
                        }
                    }
                }
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if !stats.name.isEmpty { parts.append(stats.name) }
        if stats.coreCount > 0 { parts.append("\(stats.coreCount) cores") }
        if stats.memoryTotalBytes > 0 {
            parts.append(String(format: "%.0f%% memory", stats.memoryUsagePercent))
        }
        return parts.isEmpty ? "Graphics" : parts.joined(separator: " · ")
    }

    private var gpuGradient: [Color] {
        if stats.utilizationPercent > 85 { return [.red, .orange] }
        if stats.utilizationPercent > 60 { return [.orange, .yellow] }
        return [.purple, .cyan]
    }
}
