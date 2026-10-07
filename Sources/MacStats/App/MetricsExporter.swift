import Foundation

/// Renders the session history buffer as CSV.
///
/// The header row is the documented schema — keep the column order stable so
/// exported files stay comparable across versions. Numbers use a plain `.`
/// decimal separator (C locale) and no thousands separators.
enum MetricsExporter {
    static let header = "timestamp,cpu_percent,memory_percent,memory_used_mb,"
        + "network_up_bps,network_down_bps,disk_read_bps,disk_write_bps,"
        + "gpu_percent,cpu_temp_c,battery_percent"

    static func makeCSV(samples: [MetricSample]) -> String {
        var lines = [header]
        lines.reserveCapacity(samples.count + 1)

        let iso = ISO8601DateFormatter()
        for sample in samples {
            let temperature = sample.cpuTemperatureCelsius.map { number($0, decimals: 1) } ?? ""
            lines.append(
                [
                    iso.string(from: sample.timestamp),
                    number(sample.cpuPercent, decimals: 1),
                    number(sample.memoryPercent, decimals: 1),
                    String(sample.memoryUsedBytes / 1_048_576),
                    number(sample.networkUpBytesPerSec, decimals: 0),
                    number(sample.networkDownBytesPerSec, decimals: 0),
                    number(sample.diskReadBytesPerSec, decimals: 0),
                    number(sample.diskWriteBytesPerSec, decimals: 0),
                    number(sample.gpuPercent, decimals: 1),
                    temperature,
                    number(sample.batteryPercent, decimals: 0),
                ].joined(separator: ",")
            )
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func suggestedFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "MacStats-\(formatter.string(from: now)).csv"
    }

    private static func number(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", value)
    }
}
