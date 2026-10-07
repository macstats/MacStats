import SwiftUI

struct NetworkDetailView: View, Equatable {
    let stats: NetworkStats
    let uploadTrace: [Double]
    let downloadTrace: [Double]
    var connections: ConnectionStats = ConnectionStats()

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

                if connections.isAvailable {
                    ConnectionChips(connections: connections)
                }
            }
        }
    }
}

/// TCP state counts from `ConnectionMonitor`.
private struct ConnectionChips: View {
    let connections: ConnectionStats

    var body: some View {
        HStack(spacing: DS.Space.m) {
            chip(label: "Established", value: connections.established, color: DS.Palette.ok)
            chip(label: "Listening", value: connections.listening, color: DS.Palette.down)
            chip(label: "Time wait", value: connections.timeWait, color: DS.Palette.warn)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "TCP connections: \(connections.established) established, "
                + "\(connections.listening) listening, \(connections.timeWait) time wait"
        )
    }

    private func chip(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text("\(value)")
                .font(DS.Text.mono(10, weight: .medium))
                .foregroundColor(DS.Palette.primary)
                .monospacedDigit()
            Text(label)
                .font(DS.Text.micro)
                .foregroundColor(DS.Palette.tertiary)
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
