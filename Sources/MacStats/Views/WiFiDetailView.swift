import SwiftUI

struct WiFiDetailView: View {
    let stats: WiFiStats

    var body: some View {
        SectionCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    ZStack {
                        Image(systemName: wifiIcon)
                            .font(.system(size: 20))
                            .foregroundColor(stats.isActive && !stats.ssid.isEmpty ? .blue : .secondary)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text("WiFi")
                                .font(.system(size: 13, weight: .semibold))
                            if stats.isActive && !stats.ssid.isEmpty {
                                SignalBars(bars: stats.signalBars)
                            }
                        }
                        Text(stats.isActive && !stats.ssid.isEmpty ? stats.ssid : "Not Connected")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if stats.isActive && stats.rssi != 0 {
                        Text("\(stats.rssi) dBm")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(rssiColor)
                    }
                }

                if stats.isActive && !stats.ssid.isEmpty {
                    VStack(spacing: 4) {
                        if !stats.localIP.isEmpty {
                            StatRowView(
                                label: "IP Address",
                                value: stats.localIP,
                                icon: "number",
                                iconColor: .blue
                            )
                        }
                        if stats.channel > 0 {
                            StatRowView(
                                label: "Channel",
                                value: "\(stats.channel) (\(stats.channel <= 14 ? "2.4 GHz" : "5 GHz"))",
                                icon: "antenna.radiowaves.left.and.right",
                                iconColor: .purple
                            )
                        }
                    }
                }
            }
        }
    }

    private var wifiIcon: String {
        if !stats.isActive || stats.ssid.isEmpty { return "wifi.slash" }
        switch stats.signalBars {
        case 4, 3: return "wifi"
        case 2:    return "wifi"
        case 1:    return "wifi"
        default:   return "wifi.exclamationmark"
        }
    }

    private var rssiColor: Color {
        switch stats.signalBars {
        case 4: return .green
        case 3: return .blue
        case 2: return .orange
        default: return .red
        }
    }
}

private struct SignalBars: View {
    let bars: Int

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(i < bars ? barColor : Color.secondary.opacity(0.2))
                    .frame(width: 3, height: CGFloat(4 + i * 2))
            }
        }
        .frame(height: 10, alignment: .bottom)
    }

    private var barColor: Color {
        switch bars {
        case 4: return .green
        case 3: return .blue
        case 2: return .orange
        default: return .red
        }
    }
}
