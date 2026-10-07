import Foundation

/// Single source of truth for every number the app renders.
/// Monospaced digits plus stable field widths keep the UI from jittering.
enum Format {
    private static let kb = 1024.0
    private static let mb = kb * 1024
    private static let gb = mb * 1024
    private static let tb = gb * 1024

    /// "675 MB", "9.6 GB" — for labels inside panels.
    static func bytes(_ value: UInt64) -> String {
        let v = Double(value)
        if v >= tb { return String(format: "%.1f TB", v / tb) }
        if v >= gb { return String(format: "%.1f GB", v / gb) }
        if v >= mb { return String(format: "%.0f MB", v / mb) }
        if v >= kb { return String(format: "%.0f KB", v / kb) }
        return "\(value) B"
    }

    /// "9.6G" — for tight spaces such as the menu bar and legend chips.
    static func compactBytes(_ value: UInt64) -> String {
        let v = Double(value)
        if v >= tb { return String(format: "%.1fT", v / tb) }
        if v >= gb { return String(format: "%.1fG", v / gb) }
        if v >= mb { return String(format: "%.0fM", v / mb) }
        if v >= kb { return String(format: "%.0fK", v / kb) }
        return "\(value)B"
    }

    /// "1.71 MB/s" — human readable transfer rate.
    static func speed(_ bps: Double) -> String {
        guard bps.isFinite, bps > 0 else { return "0 B/s" }
        if bps >= gb { return String(format: "%.2f GB/s", bps / gb) }
        if bps >= mb { return String(format: "%.2f MB/s", bps / mb) }
        if bps >= kb { return String(format: "%.1f KB/s", bps / kb) }
        return String(format: "%.0f B/s", bps)
    }

    /// "1.7M" — fixed 4-character cell for the menu bar.
    static func menuBarSpeed(_ bps: Double) -> String {
        guard bps.isFinite, bps > 0 else { return "0B" }
        if bps >= gb { return String(format: "%4.1fG", bps / gb) }
        if bps >= mb {
            let m = bps / mb
            return m < 10 ? String(format: "%3.1fM", m) : String(format: "%4.0fM", m)
        }
        if bps >= kb {
            let k = bps / kb
            return k < 10 ? String(format: "%3.1fK", k) : String(format: "%4.0fK", k)
        }
        return String(format: "%3.0fB", bps)
    }

    /// "42%" / "42.3%"
    static func percent(_ value: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f%%", value)
    }

    /// "2d 15h 58m" → "15h 58m" → "58m" → "42s"
    static func uptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }

    /// "4h 32m" / "32m" — battery time estimates.
    static func minutes(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// "now", "3s ago", "2m ago" — footer freshness stamp.
    static func age(since date: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 2 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }
}
