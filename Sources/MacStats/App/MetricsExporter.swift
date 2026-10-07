import Foundation

/// Renders the session history buffer as CSV.
enum MetricsExporter {
    static let header = "timestamp,cpu_percent,memory_percent,memory_used_mb,"
        + "network_up_bps,network_down_bps,disk_read_bps,disk_write_bps,"
        + "gpu_percent,cpu_temp_c,battery_percent"

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func makeCSV(samples: [MetricSample]) -> String {
        var lines = [header]
        lines.reserveCapacity(samples.count + 1)

        for sample in samples {
            let fields = [
                timestampFormatter.string(from: sample.timestamp),
                number(sample.cpuPercent, decimals: 1),
                number(sample.memoryPercent, decimals: 1),
                number(Double(sample.memoryUsedBytes) / (1024 * 1024), decimals: 1),
                number(sample.networkUpBytesPerSec, decimals: 0),
                number(sample.networkDownBytesPerSec, decimals: 0),
                number(sample.diskReadBytesPerSec, decimals: 0),
                number(sample.diskWriteBytesPerSec, decimals: 0),
                number(sample.gpuPercent, decimals: 1),
                sample.cpuTemperatureCelsius.map { number($0, decimals: 1) } ?? "",
                number(sample.batteryPercent, decimals: 1),
            ]
            lines.append(fields.joined(separator: ","))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func suggestedFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "MacStats-\(formatter.string(from: now)).csv"
    }

    // `String(format:)` without a locale is locale-independent ("." decimal
    // separator, no grouping), which is exactly what a CSV schema wants.
    private static func number(_ value: Double, decimals: Int) -> String {
        let text = String(format: "%.\(decimals)f", value)
        return text.replacingOccurrences(of: ",", with: "")
    }
}
