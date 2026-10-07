import SwiftUI

struct WiFiDetailView: View, Equatable {
    let stats: WiFiStats

    private var isConnected: Bool { stats.isActive && !stats.ssid.isEmpty }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                PanelHeader("Wi-Fi", symbol: isConnected ? "wifi" : "wifi.slash") {
                    if isConnected {
                        HStack(spacing: DS.Space.s) {
                            SignalBars(bars: stats.signalBars, level: stats.signalLevel)
                            Text("\(stats.rssi) dBm")
                                .font(DS.Text.mono(10, weight: .medium))
                                .foregroundColor(stats.signalLevel.color)
                                .monospacedDigit()
                        }
                    } else {
                        Text("Not connected")
                            .font(DS.Text.label)
                            .foregroundColor(DS.Palette.secondary)
                    }
                }

                if isConnected {
                    VStack(spacing: 2) {
                        StatRowView(
                            label: "Network",
                            value: stats.ssid,
                            icon: "wifi",
                            iconColor: DS.Palette.secondary
                        )
                        if !stats.localIP.isEmpty {
                            StatRowView(
                                label: "IP Address",
                                value: stats.localIP,
                                icon: "number",
                                iconColor: DS.Palette.secondary
                            )
                        }
                        if stats.channel > 0 {
                            StatRowView(
                                label: "Channel",
                                value: "\(stats.channel) · \(stats.bandLabel)",
                                icon: "antenna.radiowaves.left.and.right",
                                iconColor: DS.Palette.secondary
                            )
                        }
                        if stats.transmitRateMbps > 0 {
                            StatRowView(
                                label: "Link Rate",
                                value: String(format: "%.0f Mbps", stats.transmitRateMbps),
                                icon: "speedometer",
                                iconColor: DS.Palette.secondary
                            )
                        }
                    }
                }
            }
        }
    }
}
