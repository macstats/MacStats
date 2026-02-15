import SwiftUI

struct SystemInfoHeader: View {
    let uptime: TimeInterval
    var thermalLevel: ThermalLevel = .nominal

    private var macName: String {
        Host.current().localizedName ?? "Mac"
    }

    private var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var uptimeText: String {
        let total = Int(uptime)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let mins = (total % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 22))
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(macName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if thermalLevel != .nominal {
                        ThermalBadge(level: thermalLevel)
                    }
                }
                Text("\(osVersion)  ·  up \(uptimeText)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct ThermalBadge: View {
    let level: ThermalLevel

    private var color: Color {
        switch level {
        case .nominal:  return .green
        case .fair:     return .yellow
        case .serious:  return .orange
        case .critical: return .red
        }
    }

    private var icon: String {
        switch level {
        case .nominal:  return "thermometer.low"
        case .fair:     return "thermometer.medium"
        case .serious:  return "thermometer.high"
        case .critical: return "flame.fill"
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(level.label)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(color.opacity(0.15))
        )
    }
}
