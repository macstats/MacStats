import Foundation

/// Headless diagnostics: `MacStats --dump-once` prints one real sample and exits.
/// Used by CI and by the feature agents to verify monitors without a GUI session.
enum DumpOnce {
    static func run() {
        let monitor = SystemMonitor()
        // Tick through enough refreshes that the slow-cadence monitors
        // (disk I/O, SMC sensors, TCP connections) produce at least one delta.
        var stats = monitor.refresh()
        for _ in 0..<6 {
            Thread.sleep(forTimeInterval: 0.6)
            stats = monitor.refresh()
        }

        let iso = ISO8601DateFormatter()
        print("MacStats dump @ \(iso.string(from: Date()))")
        print("CPU: \(fmt(stats.cpu.totalUsage))% cores=\(stats.cpu.coreCount) per-core=[\(stats.cpu.perCoreUsage.map { fmt($0, 1) }.joined(separator: ", "))]")
        print("Memory: \(fmt(stats.memory.usagePercent))% used=\(bytes(stats.memory.usedBytes)) total=\(bytes(stats.memory.totalBytes))")
        print("Network: up=\(rate(stats.network.bytesSentPerSec)) down=\(rate(stats.network.bytesReceivedPerSec)) session-up=\(bytes(stats.network.sessionSentBytes)) session-down=\(bytes(stats.network.sessionReceivedBytes)) peak-up=\(rate(stats.network.peakSentPerSec)) peak-down=\(rate(stats.network.peakReceivedPerSec))")
        print("Disk: used=\(fmt(stats.disk.usagePercent))% read=\(rate(stats.disk.readBytesPerSec)) write=\(rate(stats.disk.writeBytesPerSec)) session-read=\(bytes(stats.disk.sessionReadBytes)) session-write=\(bytes(stats.disk.sessionWriteBytes))")
        print("GPU: available=\(stats.gpu.isAvailable) name=\"\(stats.gpu.name)\" util=\(fmt(stats.gpu.utilizationPercent))% mem=\(bytes(stats.gpu.memoryUsedBytes))/\(bytes(stats.gpu.memoryTotalBytes)) cores=\(stats.gpu.coreCount)")
        print("Sensors: available=\(stats.sensors.isAvailable) temp=\(stats.sensors.cpuTemperature.map { fmt($0) } ?? "nil") key=\"\(stats.sensors.temperatureKey)\" fans=[\(stats.sensors.fans.map { "F\($0.index)=\($0.rpm)rpm" }.joined(separator: ", "))]")
        print("Connections: available=\(stats.connections.isAvailable) established=\(stats.connections.established) listening=\(stats.connections.listening) time-wait=\(stats.connections.timeWait) close-wait=\(stats.connections.closeWait) other=\(stats.connections.other) ports=[\(stats.connections.listeningPorts.map(String.init).joined(separator: ", "))]")

        let processes = monitor.topProcesses(5, sort: .cpu, query: "")
        print("Processes (top 5 by CPU):")
        for proc in processes {
            print("  - \(proc.name)(\(proc.pid)) cpu=\(fmt(proc.cpuPercent))% mem=\(fmt(proc.memPercent))%")
        }

        let alertCenter = AlertCenter(postsNotifications: false)
        let alerts = alertCenter.evaluate(stats)
        print("Alerts: enabled=\(alertCenter.isEnabled) active=\(alerts.count) \(alerts.map { "\($0.id):\($0.message)" }.joined(separator: " | "))")

        let csv = MetricsExporter.makeCSV(samples: [])
        print("CSV: header=\"\(csv.split(separator: "\n").first.map(String.init) ?? "")\"")

        print("dump: ok")
    }

    private static func fmt(_ value: Double, _ decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private static func bytes(_ value: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var amount = Double(value)
        var unit = 0
        while amount >= 1024, unit < units.count - 1 {
            amount /= 1024
            unit += 1
        }
        return String(format: "%.2f%@", amount, units[unit])
    }

    private static func rate(_ value: Double) -> String {
        bytes(UInt64(max(value, 0))) + "/s"
    }
}
