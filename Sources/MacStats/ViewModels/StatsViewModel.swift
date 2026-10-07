import Foundation
import Combine

final class StatsViewModel: ObservableObject {
    // SwiftUI-observed properties — only updated when popover is visible
    @Published var stats = SystemStats()
    @Published var cpuHistory: [Double] = []
    @Published var netUpHistory: [Double] = []
    @Published var netDownHistory: [Double] = []
    @Published var diskReadHistory: [Double] = []
    @Published var diskWriteHistory: [Double] = []
    @Published var gpuHistory: [Double] = []
    @Published var topProcesses: [TopProcess] = []
    @Published var activeAlerts: [ActiveAlert] = []
    @Published var uptime: TimeInterval = 0

    // Process browser controls (bound by ProcessListView)
    @Published var processSort: ProcessSortMode = .cpu
    @Published var processSearch: String = ""
    @Published var processLimit: Int = 10
    @Published var processActionMessage: String?

    // Alert master switch (mirrored into AlertCenter/UserDefaults)
    @Published var alertsEnabled: Bool = true

    // Lightweight callback for status bar (always fires, no SwiftUI overhead)
    var onStatusBarUpdate: ((SystemStats, [Double]) -> Void)?

    let alertCenter = AlertCenter()

    // Popover visibility gate
    var isPopoverVisible = false {
        didSet {
            if isPopoverVisible && !oldValue {
                // Popover just opened — push current state to SwiftUI immediately
                DispatchQueue.main.async { [self] in
                    self.stats = self.currentStats
                    self.cpuHistory = self.currentCPUHistory
                    self.netUpHistory = self.currentNetUpHistory
                    self.netDownHistory = self.currentNetDownHistory
                    self.diskReadHistory = self.currentDiskReadHistory
                    self.diskWriteHistory = self.currentDiskWriteHistory
                    self.gpuHistory = self.currentGPUHistory
                    self.topProcesses = self.currentProcesses
                    self.activeAlerts = self.currentAlerts
                    self.uptime = ProcessInfo.processInfo.systemUptime
                }
                refreshProcesses()
            }
        }
    }

    // Raw state (always current, not @Published)
    private(set) var currentStats = SystemStats()
    /// Rolling session history used by the CSV export (trimmed to `maxSessionSamples`).
    private(set) var sessionSamples: [MetricSample] = []
    private var currentCPUHistory: [Double] = []
    private var currentNetUpHistory: [Double] = []
    private var currentNetDownHistory: [Double] = []
    private var currentDiskReadHistory: [Double] = []
    private var currentDiskWriteHistory: [Double] = []
    private var currentGPUHistory: [Double] = []
    private var currentProcesses: [TopProcess] = []
    private var currentAlerts: [ActiveAlert] = []

    private let monitor = SystemMonitor()
    private var timerSource: DispatchSourceTimer?
    private let historyLength = 30
    private let maxSessionSamples = 2400   // ~2 hours at a 3s tick
    private var tickCount = 0
    private let workQueue = DispatchQueue(label: "com.macstats.monitor", qos: .utility)

    // Shadow copies of the process query so the monitor queue never reads
    // main-thread @Published state directly.
    private let queryLock = NSLock()
    private var querySort: ProcessSortMode = .cpu
    private var querySearch: String = ""
    private var queryLimit: Int = 10
    private var searchDebounce: DispatchWorkItem?

    init() {
        alertsEnabled = alertCenter.isEnabled
    }

    func start() {
        // Prime monitors
        workQueue.async { [weak self] in
            guard let self else { return }
            _ = self.monitor.refresh()
        }

        let source = DispatchSource.makeTimerSource(queue: workQueue)
        source.schedule(deadline: .now() + 3.0, repeating: 3.0, leeway: .milliseconds(500))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let s = self.monitor.refresh()
            let (sort, search, limit) = self.processQuerySnapshot()
            let processEvery = self.isPopoverVisible ? 2 : 5
            let procs = self.tickCount % processEvery == 0
                ? self.monitor.topProcesses(count: limit, sort: sort, query: search)
                : nil
            let alerts = self.alertCenter.evaluate(s)
            self.tickCount += 1

            DispatchQueue.main.async {
                // Always update raw state
                self.currentStats = s
                if let procs { self.currentProcesses = procs }
                self.currentAlerts = alerts
                self.appendRawHistory(s)
                self.appendSessionSample(s)

                // Always notify status bar (lightweight, no SwiftUI)
                self.onStatusBarUpdate?(s, self.currentCPUHistory)

                // Only push to SwiftUI when popover is visible
                if self.isPopoverVisible {
                    self.stats = s
                    self.cpuHistory = self.currentCPUHistory
                    self.netUpHistory = self.currentNetUpHistory
                    self.netDownHistory = self.currentNetDownHistory
                    self.diskReadHistory = self.currentDiskReadHistory
                    self.diskWriteHistory = self.currentDiskWriteHistory
                    self.gpuHistory = self.currentGPUHistory
                    if let procs { self.topProcesses = procs }
                    self.activeAlerts = self.currentAlerts
                    self.uptime = ProcessInfo.processInfo.systemUptime
                }
            }
        }
        source.resume()
        timerSource = source

        // Initial data
        workQueue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            let s = self.monitor.refresh()
            let (sort, search, limit) = self.processQuerySnapshot()
            let procs = self.monitor.topProcesses(count: limit, sort: sort, query: search)

            DispatchQueue.main.async {
                self.currentStats = s
                self.currentProcesses = procs
                self.appendRawHistory(s)
                self.appendSessionSample(s)
                self.onStatusBarUpdate?(s, self.currentCPUHistory)

                self.stats = s
                self.topProcesses = procs
                self.uptime = ProcessInfo.processInfo.systemUptime
                self.cpuHistory = self.currentCPUHistory
            }
        }
    }

    // MARK: - Process browser

    func setProcessSort(_ mode: ProcessSortMode) {
        processSort = mode
        updateQuerySnapshot(sort: mode, search: nil, limit: nil)
        refreshProcesses()
    }

    func setProcessSearch(_ text: String) {
        processSearch = text
        updateQuerySnapshot(sort: nil, search: text, limit: nil)
        refreshProcesses()
    }

    /// Debounced variant used by the search field: the text updates immediately,
    /// the (comparatively expensive) rescan happens 0.3s after the last keystroke.
    func updateProcessSearch(_ text: String) {
        processSearch = text
        searchDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.setProcessSearch(text)
        }
        searchDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Surfaces a transient error in the process card (e.g. kill denied).
    func reportProcessError(_ message: String) {
        processActionMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            if self?.processActionMessage == message {
                self?.processActionMessage = nil
            }
        }
    }

    func setProcessLimit(_ limit: Int) {
        processLimit = limit
        updateQuerySnapshot(sort: nil, search: nil, limit: limit)
        refreshProcesses()
    }

    func refreshProcesses() {
        let (sort, search, limit) = processQuerySnapshot()
        workQueue.async { [weak self] in
            guard let self else { return }
            let procs = self.monitor.topProcesses(count: limit, sort: sort, query: search)
            DispatchQueue.main.async {
                self.currentProcesses = procs
                if self.isPopoverVisible { self.topProcesses = procs }
            }
        }
    }

    /// Sends SIGTERM (`force == false`) or SIGKILL (`force == true`).
    @discardableResult
    func kill(pid: Int32, force: Bool) -> Bool {
        let ok = monitor.killProcess(pid: pid, force: force)
        if ok { refreshProcesses() }
        return ok
    }

    private func processQuerySnapshot() -> (ProcessSortMode, String, Int) {
        queryLock.lock()
        defer { queryLock.unlock() }
        return (querySort, querySearch, queryLimit)
    }

    private func updateQuerySnapshot(sort: ProcessSortMode?, search: String?, limit: Int?) {
        queryLock.lock()
        if let sort { querySort = sort }
        if let search { querySearch = search }
        if let limit { queryLimit = limit }
        queryLock.unlock()
    }

    // MARK: - Alerts

    func setAlertsEnabled(_ enabled: Bool) {
        alertsEnabled = enabled
        alertCenter.isEnabled = enabled
    }

    func requestNotificationAuthorization() {
        alertCenter.requestAuthorization()
    }

    func sendTestNotification() {
        alertCenter.postTestNotification()
    }

    // MARK: - Export

    func csvSnapshot() -> String {
        MetricsExporter.makeCSV(samples: sessionSamples)
    }

    private func appendRawHistory(_ s: SystemStats) {
        currentCPUHistory.append(s.cpu.totalUsage)
        if currentCPUHistory.count > historyLength {
            currentCPUHistory.removeFirst(currentCPUHistory.count - historyLength)
        }
        currentNetUpHistory.append(s.network.bytesSentPerSec)
        if currentNetUpHistory.count > historyLength {
            currentNetUpHistory.removeFirst(currentNetUpHistory.count - historyLength)
        }
        currentNetDownHistory.append(s.network.bytesReceivedPerSec)
        if currentNetDownHistory.count > historyLength {
            currentNetDownHistory.removeFirst(currentNetDownHistory.count - historyLength)
        }
        currentDiskReadHistory.append(s.disk.readBytesPerSec)
        if currentDiskReadHistory.count > historyLength {
            currentDiskReadHistory.removeFirst(currentDiskReadHistory.count - historyLength)
        }
        currentDiskWriteHistory.append(s.disk.writeBytesPerSec)
        if currentDiskWriteHistory.count > historyLength {
            currentDiskWriteHistory.removeFirst(currentDiskWriteHistory.count - historyLength)
        }
        currentGPUHistory.append(s.gpu.utilizationPercent)
        if currentGPUHistory.count > historyLength {
            currentGPUHistory.removeFirst(currentGPUHistory.count - historyLength)
        }
    }

    private func appendSessionSample(_ s: SystemStats) {
        sessionSamples.append(MetricSample(
            timestamp: Date(),
            cpuPercent: s.cpu.totalUsage,
            memoryPercent: s.memory.usagePercent,
            memoryUsedBytes: s.memory.usedBytes,
            networkUpBytesPerSec: s.network.bytesSentPerSec,
            networkDownBytesPerSec: s.network.bytesReceivedPerSec,
            diskReadBytesPerSec: s.disk.readBytesPerSec,
            diskWriteBytesPerSec: s.disk.writeBytesPerSec,
            gpuPercent: s.gpu.utilizationPercent,
            cpuTemperatureCelsius: s.sensors.cpuTemperature,
            batteryPercent: s.battery.isPresent ? s.battery.chargePercent : 0
        ))
        if sessionSamples.count > maxSessionSamples {
            sessionSamples.removeFirst(sessionSamples.count - maxSessionSamples)
        }
    }

    func stop() {
        timerSource?.cancel()
        timerSource = nil
    }

    deinit { stop() }
}
