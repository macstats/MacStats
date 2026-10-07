import SwiftUI

struct NetworkDetailView: View, Equatable {
    let stats: NetworkStats
    let uploadTrace: [Double]
    let downloadTrace: [Double]

    /// Both directions share one scale so the two traces stay comparable —
    /// independently auto-scaled charts made a quiet line look busy.
    private var scale: Double {
        let peak = Swift.max(uploadTrace.max() ?? 0, downloadTrace.max() ?? 0)
        let floor = 64 * 1024.0    // 64 KB/s keeps idle noise from filling the chart
        return Swift.max(peak * 1.1, floor)
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                PanelHeader("Network", symbol: "network") {
                    Text("↑ \(Format.compactBytes(stats.sessionSentBytes))  ↓ \(Format.compactBytes(stats.sessionReceivedBytes))")
                        .font(DS.Text.mono(10))
                        .foregroundColor(DS.Palette.tertiary)
                }

                ChannelRow(
                    label: "Download",
                    symbol: "arrow.down",
                    color: DS.Palette.down,
                    speed: stats.bytesReceivedPerSec,
                    trace: downloadTrace,
                    scale: scale
                )

                ChannelRow(
                    label: "Upload",
                    symbol: "arrow.up",
                    color: DS.Palette.up,
                    speed: stats.bytesSentPerSec,
                    trace: uploadTrace,
                    scale: scale
                )
            }
        }
    }
}

private struct ChannelRow: View {
    let label: String
    let symbol: String
    let color: Color
    let speed: Double
    let trace: [Double]
    let scale: Double

    var body: some View {
        HStack(spacing: DS.Space.s) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color)
                Text(label)
                    .font(DS.Text.micro)
                    .foregroundColor(DS.Palette.secondary)
            }
            .frame(width: 66, alignment: .leading)

            TraceView(values: trace, maxValue: scale, color: color, showsFill: false, gridLines: 1)
                .frame(height: 22)

            Text(Format.speed(speed))
                .font(DS.Text.mono(11, weight: .medium))
                .foregroundColor(DS.Palette.primary)
                .monospacedDigit()
                .frame(width: 84, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(Format.speed(speed))")
    }
}
