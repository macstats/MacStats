import Foundation

/// Orchestrates the individual monitors and decides how often each one is
/// allowed to touch the system.
///
/// Two ideas keep the app cheap:
/// 1. **Cost-tiered cadence** — CPU/memory/network are single cheap syscalls
///    and run every tick; disk/battery/Wi-Fi are comparatively expensive and
///    are time-scheduled on their own slower clocks.
/// 2. **Change-driven backoff** — when a slow value comes back identical,
///    its next read is pushed out exponentially (capped), so an idle Mac
///    settles into the minimum possible amount of I/O.
final class SystemMonitor {
    enum Mode {
        case interactive   // popover is open — the user is watching
        case background    // running quietly in the menu bar
    }

    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let diskMonitor = DiskMonitor()
    private let processMonitor = ProcessMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let wifiMonitor = WiFiMonitor()
    private let gpuMonitor = GPUMonitor()
    private let sensorMonitor = SensorMonitor()
    private let connectionMonitor = ConnectionMonitor()

    private var cachedDisk = DiskStats()
    private var cachedBattery = BatteryStats()
    private var cachedWifi = WiFiStats()
    private var cachedGPU = GPUStats()
    private var cachedSensors = SensorStats()
    private var cachedConnections = ConnectionStats()

    // Time-based schedules (seconds since boot).
    private var nextDiskRead: TimeInterval = 0
    private var nextBatteryRead: TimeInterval = 0
    private var nextWiFiRead: TimeInterval = 0
    private var nextGPURead: TimeInterval = 0
    private var nextSensorRead: TimeInterval = 0
    private var nextConnectionRead: TimeInterval = 0
    private var diskInterval: TimeInterval = 0
    private var batteryInterval: TimeInterval = 0
    private var wifiInterval: TimeInterval = 0
    private var gpuInterval: TimeInterval = 0
    private var sensorInterval: TimeInterval = 0
    private var connectionInterval: TimeInterval = 0

    /// Forces the next refresh to re-read every slow component, e.g. after
    /// wake, network changes, or when the popover opens.
    func invalidateSlowCaches() {
        nextDiskRead = 0
        nextBatteryRead = 0
        nextWiFiRead = 0
        nextGPURead = 0
        nextSensorRead = 0
        nextConnectionRead = 0
        diskInterval = 0
        batteryInterval = 0
        wifiInterval = 0
        gpuInterval = 0
        sensorInterval = 0
        connectionInterval = 0
        wifiMonitor.invalidate()
    }

    func refresh(mode: Mode = .background) -> SystemStats {
        let now = ProcessInfo.processInfo.systemUptime
        let interactive = mode == .interactive

        let cpu = cpuMonitor.read()
        let memory = memoryMonitor.read()
        let network = networkMonitor.read()

        if now >= nextDiskRead {
            let fresh = diskMonitor.read()
            let changed = fresh != cachedDisk
            cachedDisk = fresh
            diskInterval = Self.nextInterval(
                current: diskInterval,
                base: interactive ? 4 : 15,
                maximum: interactive ? 30 : 120,
                changed: changed
            )
            nextDiskRead = now + diskInterval
        }

        if now >= nextBatteryRead {
            let fresh = batteryMonitor.read()
            let changed = fresh != cachedBattery
            cachedBattery = fresh
            batteryInterval = Self.nextInterval(
                current: batteryInterval,
                base: interactive ? 8 : 30,
                maximum: interactive ? 30 : 120,
                changed: changed
            )
            nextBatteryRead = now + batteryInterval
        }

        if now >= nextWiFiRead {
            let fresh = wifiMonitor.read()
            let changed = fresh != cachedWifi
            cachedWifi = fresh
            wifiInterval = Self.nextInterval(
                current: wifiInterval,
                base: interactive ? 5 : 20,
                maximum: interactive ? 20 : 90,
                changed: changed
            )
            nextWiFiRead = now + wifiInterval
        }

        // GPU utilization moves quickly; keep a short clock so the trace stays
        // honest, but still back off while nothing changes.
        if now >= nextGPURead {
            let fresh = gpuMonitor.read()
            let changed = fresh != cachedGPU
            cachedGPU = fresh
            gpuInterval = Self.nextInterval(
                current: gpuInterval,
                base: interactive ? 3 : 6,
                maximum: interactive ? 15 : 60,
                changed: changed
            )
            nextGPURead = now + gpuInterval
        }

        // SMC reads are the most expensive monitor; they only matter for the
        // thermal card, so they run on a slow clock.
        if now >= nextSensorRead {
            let fresh = sensorMonitor.read()
            let changed = fresh != cachedSensors
            cachedSensors = fresh
            sensorInterval = Self.nextInterval(
                current: sensorInterval,
                base: interactive ? 15 : 45,
                maximum: interactive ? 60 : 180,
                changed: changed
            )
            nextSensorRead = now + sensorInterval
        }

        // The TCP table comes from spawning `netstat`; it is by far the most
        // expensive slow monitor, so it runs on the longest clock.
        if now >= nextConnectionRead {
            let fresh = connectionMonitor.read()
            let changed = fresh != cachedConnections
            cachedConnections = fresh
            connectionInterval = Self.nextInterval(
                current: connectionInterval,
                base: interactive ? 30 : 90,
                maximum: interactive ? 120 : 300,
                changed: changed
            )
            nextConnectionRead = now + connectionInterval
        }

        let thermal: ThermalLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  thermal = .nominal
        case .fair:     thermal = .fair
        case .serious:  thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .nominal
        }

        return SystemStats(
            cpu: cpu,
            memory: memory,
            network: network,
            disk: cachedDisk,
            battery: cachedBattery,
            wifi: cachedWifi,
            gpu: cachedGPU,
            sensors: cachedSensors,
            connections: cachedConnections,
            thermalLevel: thermal
        )
    }

    func topProcesses(
        _ count: Int = 5,
        sort: ProcessSortKey = .cpu,
        query: String = ""
    ) -> [TopProcess] {
        processMonitor.top(count, sort: sort, query: query)
    }

    /// Sends SIGTERM (`force == false`) or SIGKILL (`force == true`).
    @discardableResult
    func killProcess(pid: Int32, force: Bool = false) -> Bool {
        processMonitor.kill(pid: pid, force: force)
    }

    /// Diagnostic hook used by `MacStats --benchmark`: times each monitor in
    /// isolation so regressions can be attributed to a specific syscall.
    func componentBenchmarks(iterations: Int) -> [(name: String, average: Double, p95: Double)] {
        func measure(_ body: () -> Void) -> (average: Double, p95: Double) {
            // Warm up, then take the median of a few runs to shrug off noise.
            body()
            var samples: [Double] = []
            samples.reserveCapacity(iterations)
            for _ in 0..<iterations {
                let start = DispatchTime.now().uptimeNanoseconds
                body()
                let end = DispatchTime.now().uptimeNanoseconds
                samples.append(Double(end - start) / 1_000_000)
            }
            let sorted = samples.sorted()
            return (sorted.reduce(0, +) / Double(sorted.count), sorted[Int(Double(sorted.count) * 0.95)])
        }

        let components: [(String, () -> Void)] = [
            ("cpu", { _ = self.cpuMonitor.read() }),
            ("memory", { _ = self.memoryMonitor.read() }),
            ("network", { _ = self.networkMonitor.read() }),
            ("disk", { _ = self.diskMonitor.read() }),
            ("battery", { _ = self.batteryMonitor.read() }),
            ("wifi", { _ = self.wifiMonitor.read() }),
            ("gpu", { _ = self.gpuMonitor.read() }),
            ("sensors", { _ = self.sensorMonitor.read() }),
            ("connections", { _ = self.connectionMonitor.read() }),
            ("processes", { _ = self.processMonitor.top(5) }),
        ]

        return components.map { name, body in
            let result = measure(body)
            return (name, result.average, result.p95)
        }
    }

    /// Unchanged values back off geometrically; changed values snap back to base.
    private static func nextInterval(
        current: TimeInterval,
        base: TimeInterval,
        maximum: TimeInterval,
        changed: Bool
    ) -> TimeInterval {
        if changed { return base }
        return current > 0 ? Swift.min(current * 2, maximum) : base
    }
}
