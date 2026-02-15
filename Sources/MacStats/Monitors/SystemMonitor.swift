import Foundation

final class SystemMonitor {
    private let cpuMonitor = CPUMonitor()
    private let memoryMonitor = MemoryMonitor()
    private let networkMonitor = NetworkMonitor()
    private let diskMonitor = DiskMonitor()
    private let processMonitor = ProcessMonitor()
    private let batteryMonitor = BatteryMonitor()
    private let wifiMonitor = WiFiMonitor()

    private var cachedDisk = DiskStats()
    private var cachedBattery = BatteryStats()
    private var cachedWifi = WiFiStats()
    private var tickCount = 0

    func refresh() -> SystemStats {
        let cpu = cpuMonitor.read()
        let memory = memoryMonitor.read()
        let network = networkMonitor.read()

        // Disk changes slowly — read every 5th tick (~15s)
        if tickCount % 5 == 0 {
            cachedDisk = diskMonitor.read()
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
            thermalLevel: thermal
        )
    }

    func topProcesses() -> [TopProcess] {
        processMonitor.top(5)
    }
}
