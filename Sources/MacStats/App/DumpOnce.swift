import Foundation

/// Headless diagnostics: `MacStats --dump-once` prints one real sample and exits.
/// Used by CI and by feature development to verify monitors without a GUI session.
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

        // Two process samples are needed: CPU% is a delta between calls.
        _ = monitor.topProcesses(count: 5, sort: .cpu, query: "")
        Thread.sleep(forTimeInterval: 1.0)
        let processes = monitor.topProcesses(count: 5, sort: .cpu, query: "")
        print("Processes (top 5 by CPU):")
        for proc in processes {
            print("  - \(proc.name)(\(proc.pid)) cpu=\(fmt(proc.cpuPercent))% mem=\(fmt(proc.memPercent))%")
        }

        let alertCenter = AlertCenter(postsNotifications: false)
        let alerts = alertCenter.evaluate(stats)
        print("Alerts: enabled=\(alertCenter.isEnabled) active=\(alerts.count) \(alerts.map { "\($0.id):\($0.message)" }.joined(separator: " | "))")

        let csv = MetricsExporter.makeCSV(samples: [])
        print("CSV: header=\"\(csv.split(separator: "\n").first.map(String.init) ?? "")\"")
        print("CSV self-check: \(csvSelfCheck())")
        print("dump: ok")
    }

    /// `MacStats --kill-test` spawns a disposable `sleep`, finds it through the
    /// process monitor's search path and terminates it.
    static func runKillTest() {
        let monitor = SystemMonitor()

        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["600"]
        do {
            try child.run()
        } catch {
            print("kill-test: could not spawn test process: \(error)")
            return
        }

        let pid = child.processIdentifier
        Thread.sleep(forTimeInterval: 0.6)
        _ = monitor.refresh()
        Thread.sleep(forTimeInterval: 0.6)
        _ = monitor.refresh()

        let matches = monitor.topProcesses(count: 50, sort: .cpu, query: "sleep")
        print("kill-test: spawned pid=\(pid) search-matches=\(matches.count) found=\(matches.contains { $0.pid == pid })")

        let killed = monitor.killProcess(pid: pid, force: false)
        Thread.sleep(forTimeInterval: 0.4)
        print("kill-test: kill returned=\(killed) stillRunning=\(child.isRunning)")
        print("kill-test: guard pid=1 -> \(monitor.killProcess(pid: 1, force: false))")

        if child.isRunning {
            child.terminate()
        }
        print("kill-test: ok")
    }

    /// `MacStats --alert-test` feeds synthetic breaches through `AlertCenter`.
    static func runAlertTest() {
        let suite = UserDefaults(suiteName: "com.macstats.alerttest") ?? .standard
        suite.removePersistentDomain(forName: "com.macstats.alerttest")
        let center = AlertCenter(postsNotifications: false, defaults: suite)

        var stats = SystemStats()
        stats.cpu = CPUStats(totalUsage: 97.5, perCoreUsage: [97.5])
        stats.memory = MemoryStats(
            totalBytes: 16_000_000_000,
            usedBytes: 15_200_000_000,
            activeBytes: 8_000_000_000,
            wiredBytes: 3_000_000_000,
            compressedBytes: 4_200_000_000,
            freeBytes: 800_000_000
        )
        stats.disk = DiskStats(totalBytes: 1_000_000_000_000, freeBytes: 40_000_000_000)
        var battery = BatteryStats()
        battery.isPresent = true
        battery.currentCapacity = 15
        battery.maxCapacity = 100
        battery.isPluggedIn = false
        stats.battery = battery
        stats.thermalLevel = .serious

        let first = center.evaluate(stats)
        let second = center.evaluate(stats)
        print("alert-test: first-pass=\(first.map(\.id).sorted())")
        print("alert-test: second-pass=\(second.map(\.id).sorted())")
        print("alert-test: cpu-alert-title=\"\(second.first { $0.id == "cpu" }?.message ?? "none")\"")

        center.isEnabled = false
        print("alert-test: disabled-pass=\(center.evaluate(stats).map(\.id))")
        print("alert-test: ok")
    }

    /// Renders two synthetic samples and asserts the CSV schema is respected.
    private static func csvSelfCheck() -> String {
        let sample = MetricSample(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            cpuPercent: 41.25,
            memoryPercent: 63.5,
            memoryUsedBytes: 8 * 1024 * 1024 * 1024,
            networkUpBytesPerSec: 1024,
            networkDownBytesPerSec: 2048,
            diskReadBytesPerSec: 4096,
            diskWriteBytesPerSec: 8192,
            gpuPercent: 12.5,
            cpuTemperatureCelsius: nil,
            batteryPercent: 77
        )
        let csv = MetricsExporter.makeCSV(samples: [sample, sample])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).dropLast()
        guard lines.count == 3, let row = lines.last else {
            return "FAILED (lines=\(lines.count))"
        }
        let fields = row.split(separator: ",", omittingEmptySubsequences: false)
        let fieldCountOK = fields.count == 11
        let emptyTempOK = fields[9].isEmpty
        let dotDecimalOK = row.contains("41.2") && !row.contains("41,2")
        return "lines=\(lines.count) fields=\(fields.count) empty-temp=\(emptyTempOK) dot-decimal=\(dotDecimalOK) row=\"\(row)\" \(fieldCountOK && emptyTempOK && dotDecimalOK ? "PASS" : "FAIL")"
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
