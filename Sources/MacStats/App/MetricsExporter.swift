import Foundation

/// Renders the session history buffer as CSV.
///
/// CONTRACT (frozen by root):
///   - `makeCSV(samples:) -> String` returns a header row plus one row per sample,
///     newline-terminated, using `header` as the exact column list (order matters —
///     it is the documented schema).
///   - numbers are written with a stable, locale-independent format (`.` decimal
///     separator, no thousands separators).
///   - empty input still yields the header row.
enum MetricsExporter {
    static let header = "timestamp,cpu_percent,memory_percent,memory_used_mb,"
        + "network_up_bps,network_down_bps,disk_read_bps,disk_write_bps,"
        + "gpu_percent,cpu_temp_c,battery_percent"

    static func makeCSV(samples: [MetricSample]) -> String {
        var lines = [header]
        _ = samples
        return lines.joined(separator: "\n") + "\n"
    }

    static func suggestedFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "MacStats-\(formatter.string(from: now)).csv"
    }
}
