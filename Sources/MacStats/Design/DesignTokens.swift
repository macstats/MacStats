import AppKit
import SwiftUI

/// Design tokens for MacStats.
///
/// One coherent system: an 8pt spacing grid, a five-step type scale,
/// hairline-bordered panels instead of floating cards, and a restrained
/// palette where saturated color is reserved for state that matters.
enum DS {

    // MARK: - Spacing (8pt grid)

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let s: CGFloat = 5
        static let m: CGFloat = 8
        static let l: CGFloat = 12
    }

    enum Layout {
        static let popoverWidth: CGFloat = 360
        static let popoverHeight: CGFloat = 620
        static let popoverMinHeight: CGFloat = 520
        static let popoverMaxHeight: CGFloat = 640
        static let panelPadding: CGFloat = 12
        static let sectionGap: CGFloat = 8
        static let headerIcon: CGFloat = 18
        static let rowHeight: CGFloat = 18
    }

    // MARK: - Type scale (five steps, monospaced digits for every number)

    enum Text {
        /// 20pt — the single hero number per panel.
        static let metric = Font.system(size: 20, weight: .semibold, design: .rounded)
        /// 15pt — secondary readouts (network speed, tiles, list values).
        static let readout = Font.system(size: 15, weight: .semibold, design: .rounded)
        /// 12pt — panel titles.
        static let title = Font.system(size: 12, weight: .semibold)
        /// 11pt — row labels and body copy.
        static let body = Font.system(size: 11, weight: .regular)
        /// 10pt — supporting labels and inline values.
        static let label = Font.system(size: 10, weight: .medium)
        /// 9pt — metadata, column headers.
        static let micro = Font.system(size: 9, weight: .medium)

        static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    // MARK: - Motion (all respect Reduce Motion at call sites)

    enum Motion {
        static let bar = Animation.easeOut(duration: 0.35)
        static let ring = Animation.easeOut(duration: 0.45)
        static let hover = Animation.easeOut(duration: 0.12)
        static let none = Animation.linear(duration: 0)
    }

    // MARK: - Palette

    enum Palette {
        /// Interactive emphasis follows the user's system accent color.
        static let accent = Color(nsColor: .controlAccentColor)

        // Surfaces — translucent so the popover's native vibrancy shows through.
        static let panel = Color(nsColor: .controlBackgroundColor).opacity(0.62)
        static let panelRaised = Color(nsColor: .controlBackgroundColor).opacity(0.9)
        static let inset = Color(nsColor: .labelColor).opacity(0.05)
        static let hairline = Color(nsColor: .separatorColor).opacity(0.6)
        static let track = Color(nsColor: .quaternaryLabelColor).opacity(0.7)
        static let grid = Color(nsColor: .separatorColor).opacity(0.35)
        static let hover = Color(nsColor: .labelColor).opacity(0.06)

        // Text
        static let primary = Color(nsColor: .labelColor)
        static let secondary = Color(nsColor: .secondaryLabelColor)
        static let tertiary = Color(nsColor: .tertiaryLabelColor)

        // Data hues — three cool hues, used consistently app-wide.
        static let cpu = Color(nsColor: .systemBlue)
        static let memory = Color(nsColor: .systemTeal)
        static let disk = Color(nsColor: .systemIndigo)
        static let up = Color(nsColor: .systemTeal)
        static let down = Color(nsColor: .systemBlue)

        // Status — the only saturated colors; they always mean something.
        static let ok = Color(nsColor: .systemGreen)
        static let warn = Color(nsColor: .systemOrange)
        static let alert = Color(nsColor: .systemRed)

        static func status(_ level: StatusLevel) -> Color {
            switch level {
            case .normal: return ok
            case .elevated: return warn
            case .critical: return alert
            }
        }
    }
}

/// Three-level health/usage state shared by bars, rings, and badges.
enum StatusLevel: String, Equatable, Comparable {
    case normal
    case elevated
    case critical

    private var rank: Int {
        switch self {
        case .normal: return 0
        case .elevated: return 1
        case .critical: return 2
        }
    }

    static func < (lhs: StatusLevel, rhs: StatusLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Classifies a 0…1 usage fraction.
    static func usage(_ fraction: Double, elevated: Double = 0.65, critical: Double = 0.85) -> StatusLevel {
        if fraction >= critical { return .critical }
        if fraction >= elevated { return .elevated }
        return .normal
    }

    var color: Color { DS.Palette.status(self) }
}

extension Double {
    /// Clamps to 0…1.
    var unitClamped: Double { Swift.min(Swift.max(self, 0), 1) }
}
