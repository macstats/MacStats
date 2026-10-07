import Foundation

final class SystemMonitor {
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
    private var tickCount = 0

    func refresh() -> SystemStats {
        let cpu = cpuMonitor.read()
        let memory = memoryMonitor.read()
        let network = networkMonitor.read()

        // GPU utilization moves quickly — read every 2nd tick (~6s)
        if tickCount % 2 == 0 {
            cachedGPU = gpuMonitor.read()
        }

        // Disk changes slowly — read every 5th tick (~15s)
        if tickCount % 5 == 0 {
            cachedDisk = diskMonitor.read()
        }

        // SMC sensors change slowly — read every 5th tick (~15s)
        if tickCount % 5 == 0 {
            cachedSensors = sensorMonitor.read()
        }

        // TCP connection table is expensive — read every 10th tick (~30s)
        if tickCount % 10 == 0 {
            cachedConnections = connectionMonitor.read()
        }

        // Battery changes slowly — read every 15th tick (~45s)
        if tickCount % 15 == 0 {
            cachedBattery = batteryMonitor.read()
        }

        // WiFi changes slowly — read every 10th tick (~30s)
        if tickCount % 10 == 0 {
            cachedWifi = wifiMonitor.read()
        }

        let thermal: ThermalLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  thermal = .nominal
        case .fair:     thermal = .fair
        case .serious:  thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .nominal
        }

        tickCount += 1

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

    func topProcesses(count: Int = 5, sort: ProcessSortMode = .cpu, query: String = "") -> [TopProcess] {
        processMonitor.top(count, sort: sort, query: query)
    }

    func killProcess(pid: Int32, force: Bool = false) -> Bool {
        processMonitor.kill(pid: pid, force: force)
    }
}
