import Foundation

/// One row of the in-memory session history buffer.
/// Written once per monitor tick and rendered to CSV by `MetricsExporter`.
struct MetricSample {
    var timestamp: Date = Date()
    var cpuPercent: Double = 0
    var memoryPercent: Double = 0
    var memoryUsedBytes: UInt64 = 0
    var networkUpBytesPerSec: Double = 0
    var networkDownBytesPerSec: Double = 0
    var diskReadBytesPerSec: Double = 0
    var diskWriteBytesPerSec: Double = 0
    var gpuPercent: Double = 0
    var cpuTemperatureCelsius: Double? = nil
    var batteryPercent: Double = 0
}
