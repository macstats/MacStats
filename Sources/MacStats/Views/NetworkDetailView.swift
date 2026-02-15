import SwiftUI

struct NetworkDetailView: View {
    let stats: NetworkStats
    var upHistory: [Double] = []
    var downHistory: [Double] = []

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "network")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.purple)
                    Text("Network")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }

                HStack(spacing: 8) {
                    NetCard(
                        label: "Upload",
                        symbol: "arrow.up",
                        color: .teal,
                        speed: stats.bytesSentPerSec,
                        history: upHistory
                    )
                    NetCard(
                        label: "Download",
                        symbol: "arrow.down",
                        color: .purple,
                        speed: stats.bytesReceivedPerSec,
                        history: downHistory
                    )
                }
            }
        }
    }
}

private struct NetCard: View {
    let label: String
    let symbol: String
    let color: Color
    let speed: Double
    let history: [Double]

    private var maxHistory: Double {
        max(history.max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if history.count > 1 {
                SparklineView(data: history, maxValue: maxHistory, color: color)
                    .frame(height: 24)
            }

            Text(formatNetworkSpeed(speed))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.05))
        )
    }

    private func formatNetworkSpeed(_ bps: Double) -> String {
        if bps < 1024 {
            return String(format: "%.0f B/s", bps)
        } else if bps < 1024 * 1024 {
            return String(format: "%.1f KB/s", bps / 1024)
        } else if bps < 1024 * 1024 * 1024 {
            return String(format: "%.2f MB/s", bps / (1024 * 1024))
        } else {
            return String(format: "%.2f GB/s", bps / (1024 * 1024 * 1024))
        }
    }
}
