import Foundation
import SwiftUI

/// Top-of-popover identity line: which Mac this is, what it runs, and how
/// hard it is working. Kept to one compact row so real data starts immediately.
struct SystemInfoHeader: View, Equatable {
    let uptime: TimeInterval
    let thermalLevel: ThermalLevel
    let lastUpdated: Date

    /// Resolved once: `Host.current()` can hit the resolver, and this view is
    /// re-evaluated on every sample while the popover is open.
    private static let cachedMacName = Host.current().localizedName ?? "Mac"

    private static let cachedOSVersion: String = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }()

    private var macName: String { Self.cachedMacName }

    private var osVersion: String { Self.cachedOSVersion }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(macName)
                    .font(DS.Text.title)
                    .foregroundColor(DS.Palette.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("\(osVersion)  ·  up \(Format.uptime(uptime))")
                    .font(DS.Text.mono(10))
                    .foregroundColor(DS.Palette.secondary)
            }

            Spacer(minLength: DS.Space.s)

            VStack(alignment: .trailing, spacing: 3) {
                if thermalLevel != .nominal {
                    StatusChip(
                        text: thermalLevel.label,
                        symbol: thermalLevel.symbol,
                        level: thermalLevel.level
                    )
                }
                Text("updated \(Format.age(since: lastUpdated))")
                    .font(DS.Text.micro)
                    .foregroundColor(DS.Palette.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(macName), \(osVersion), uptime \(Format.uptime(uptime))")
    }
}
