import AppKit
import Combine
import Foundation

/// A status-bar-sized delivery of the latest sample.
struct StatusBarSample {
    let stats: SystemStats
    let cpuHistory: [Double]
    let revision: UInt64
}

/// Owns the sampling schedule and publishes results.
///
/// Performance model:
/// - One timer on one utility queue performs all sampling; the main thread
///   only receives already-computed values.
/// - State is published **per section**, and only when that section actually
///   changed, so opening the popover does not re-render six panels because
///   the clock ticked.
/// - The whole loop is suspended while the display is asleep or the screen is
///   locked, and the interval adapts to popover visibility, Low Power Mode,
///   and thermal pressure.
final class StatsViewModel: ObservableObject {

    // MARK: - SwiftUI state (section-scoped)

    @Published private(set) var cpu = CPUStats()
    @Published private(set) var memory = MemoryStats()
    @Published private(set) var network = NetworkStats()
    @Published private(set) var disk = DiskStats()
    @Published private(set) var battery = BatteryStats()
    @Published private(set) var wifi = WiFiStats()
    @Published private(set) var thermalLevel: ThermalLevel = .nominal

    @Published private(set) var cpuTrace: [Double] = []
    @Published private(set) var uploadTrace: [Double] = []
    @Published private(set) var downloadTrace: [Double] = []
    @Published private(set) var processes: [TopProcess] = []
    @Published private(set) var uptime: TimeInterval = 0
    @Published private(set) var lastUpdated = Date.distantPast

    // MARK: - Wiring

    /// Status-bar channel: a plain callback, deliberately outside SwiftUI.
    var onStatusBarUpdate: ((StatusBarSample) -> Void)?

    let settings: AppSettings

    /// Latest sample, main-thread confined (used by the Copy Summary action).
    private(set) var latestStats = SystemStats()

    /// Popover visibility drives the sampling mode.
    var isPopoverVisible = false {
        didSet {
            guard isPopoverVisible != oldValue else { return }
            let visible = isPopoverVisible
            workQueue.async { [weak self] in
                guard let self else { return }
                self.interactive = visible
                if visible {
                    self.forceProcessSample = true
                    self.monitor.invalidateSlowCaches()
                }
                self.reschedule(immediate: true)
            }
        }
    }

    // MARK: - Private state

    private let monitor = SystemMonitor()
    private let workQueue = DispatchQueue(label: "com.macstats.monitor", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var observers: [NSObjectProtocol] = []

    // Confined to `workQueue`.
    private var interactive = false
    private var suspended = false
    private var tickCount = 0
    private var forceProcessSample = false
    private var revision: UInt64 = 0
    private var cpuHistory = RingBuffer<Double>(capacity: 60)
    private var uploadHistory = RingBuffer<Double>(capacity: 60)
    private var downloadHistory = RingBuffer<Double>(capacity: 60)
    private var baseInterval: TimeInterval

    private let historyLength = 60
    private let processSampleCount = 5

    // MARK: - Lifecycle

    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        self.baseInterval = settings.refreshRate.seconds
        observeEnvironment()
    }

    deinit {
        timer?.cancel()
        memoryPressureSource?.cancel()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start() {
        workQueue.async { [weak self] in
            guard let self else { return }
            // Prime every monitor so the first popover is fully populated.
            let stats = self.monitor.refresh(mode: .background)
            let processes = self.monitor.topProcesses(self.processSampleCount)
            self.record(stats)
            DispatchQueue.main.async {
                self.latestStats = stats
                self.publish(stats, processes: processes, uptime: ProcessInfo.processInfo.systemUptime)
                self.emitStatusBar(stats)
            }
            self.startTimer()
        }
        observeSettings()
    }

    func stop() {
        workQueue.async { [weak self] in
            self?.timer?.cancel()
            self?.timer = nil
        }
    }

    // MARK: - Scheduling

    private func startTimer() {
        timer?.cancel()
        let interval = currentInterval()
        let source = DispatchSource.makeTimerSource(queue: workQueue)
        source.schedule(
            deadline: .now() + interval,
            repeating: interval,
            leeway: .milliseconds(Int(min(interval * 0.15, 1.0) * 1_000))
        )
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        source.resume()
        timer = source
    }

    /// Rebuilds the timer with the current interval, optionally firing right away.
    private func reschedule(immediate: Bool) {
        timer?.cancel()
        let interval = currentInterval()
        let source = DispatchSource.makeTimerSource(queue: workQueue)
        source.schedule(
            deadline: .now() + (immediate ? 0.05 : interval),
            repeating: interval,
            leeway: .milliseconds(Int(min(interval * 0.15, 1.0) * 1_000))
        )
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        source.resume()
        timer = source
    }

    /// Visibility and power state shape the cadence: fast while the user is
    /// watching, half as often in the background, slower still when the Mac
    /// is thermally or battery constrained.
    private func currentInterval() -> TimeInterval {
        var interval = interactive ? min(baseInterval, 2) : min(baseInterval * 2, 10)
        if ProcessInfo.processInfo.isLowPowerModeEnabled { interval *= 2 }
        switch ProcessInfo.processInfo.thermalState {
        case .serious: interval *= 1.5
        case .critical: interval *= 2
        default: break
        }
        return min(max(interval, 1), 30)
    }

    private func tick() {
        guard !suspended else { return }

        let mode: SystemMonitor.Mode = interactive ? .interactive : .background
        let stats = monitor.refresh(mode: mode)

        let processStride = interactive ? 2 : 6
        var processes: [TopProcess]?
        if forceProcessSample || tickCount % processStride == 0 {
            processes = monitor.topProcesses(processSampleCount)
            forceProcessSample = false
        }
        tickCount &+= 1

        let uptime = ProcessInfo.processInfo.systemUptime
        record(stats)

        // History snapshots are copied once here, off the main thread.
        let cpuSnapshot = cpuHistory.values
        let upSnapshot = uploadHistory.values
        let downSnapshot = downloadHistory.values
        revision &+= 1
        let currentRevision = revision

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.latestStats = stats
            if self.interactive {
                self.publish(
                    stats,
                    processes: processes,
                    uptime: uptime,
                    cpuTrace: cpuSnapshot,
                    uploadTrace: upSnapshot,
                    downloadTrace: downSnapshot,
                    revision: currentRevision
                )
            }
            self.onStatusBarUpdate?(
                StatusBarSample(stats: stats, cpuHistory: cpuSnapshot, revision: currentRevision)
            )
        }
    }

    private func record(_ stats: SystemStats) {
        cpuHistory.append(stats.cpu.totalUsage)
        uploadHistory.append(stats.network.bytesSentPerSec)
        downloadHistory.append(stats.network.bytesReceivedPerSec)
    }

    private func emitStatusBar(_ stats: SystemStats) {
        revision &+= 1
        onStatusBarUpdate?(
            StatusBarSample(stats: stats, cpuHistory: cpuHistory.values, revision: revision)
        )
    }

    // MARK: - Publishing (main thread)

    private func publish(
        _ stats: SystemStats,
        processes: [TopProcess]?,
        uptime newUptime: TimeInterval,
        cpuTrace: [Double] = [],
        uploadTrace: [Double] = [],
        downloadTrace: [Double] = [],
        revision: UInt64 = 0
    ) {
        // Only touch the sections that changed: each `@Published` write
        // invalidates the root view, so silence is the cheapest update.
        if cpu != stats.cpu { cpu = stats.cpu }
        if memory != stats.memory { memory = stats.memory }
        if network != stats.network { network = stats.network }
        if disk != stats.disk { disk = stats.disk }
        if battery != stats.battery { battery = stats.battery }
        if wifi != stats.wifi { wifi = stats.wifi }
        if thermalLevel != stats.thermalLevel { thermalLevel = stats.thermalLevel }
        if let processes, processes != self.processes { self.processes = processes }

        if !cpuTrace.isEmpty, cpuTrace != self.cpuTrace { self.cpuTrace = cpuTrace }
        if !uploadTrace.isEmpty, uploadTrace != self.uploadTrace { self.uploadTrace = uploadTrace }
        if !downloadTrace.isEmpty, downloadTrace != self.downloadTrace { self.downloadTrace = downloadTrace }

        // The header shows minutes, so it only needs minute-granular updates.
        let roundedUptime = (newUptime / 60).rounded(.down) * 60
        if roundedUptime != uptime { uptime = roundedUptime }

        lastUpdated = Date()
    }

    private func observeSettings() {
        settings.$refreshRate
            .dropFirst()
            .receive(on: workQueue)
            .sink { [weak self] rate in
                guard let self else { return }
                self.baseInterval = rate.seconds
                self.reschedule(immediate: false)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Environment events

    private func observeEnvironment() {
        let workspace = NSWorkspace.shared.notificationCenter

        // Sleep / wake and display sleep: suspend the whole sampling loop.
        observers.append(
            workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.setSuspended(true)
            }
        )
        observers.append(
            workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.setSuspended(false)
            }
        )
        observers.append(
            workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                self?.setSuspended(true)
            }
        )
        observers.append(
            workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.setSuspended(false)
            }
        )

        // Screen lock / unlock.
        let distributed = DistributedNotificationCenter.default()
        observers.append(
            distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
                self?.setSuspended(true)
            }
        )
        observers.append(
            distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                self?.setSuspended(false)
            }
        )

        // Thermal and power-source changes should be reflected immediately.
        observers.append(
            NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshSoon()
            }
        )
        observers.append(
            NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshSoon()
            }
        )

        startMemoryPressureMonitor()
    }

    private func startMemoryPressureMonitor() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: workQueue
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = source.data
            let pressure: MemoryPressure
            if event.contains(.critical) {
                pressure = .critical
            } else if event.contains(.warning) {
                pressure = .warning
            } else {
                pressure = .normal
            }
            DispatchQueue.main.async {
                if self.memory.pressure != pressure {
                    self.memory.pressure = pressure
                }
            }
            self.refreshSoon()
        }
        source.resume()
        memoryPressureSource = source
    }

    private func setSuspended(_ suspended: Bool) {
        workQueue.async { [weak self] in
            guard let self, self.suspended != suspended else { return }
            self.suspended = suspended
            if suspended {
                self.timer?.cancel()
                self.timer = nil
            } else {
                self.tickCount = 0
                self.monitor.invalidateSlowCaches()
                self.tick()
                self.reschedule(immediate: false)
            }
        }
    }

    /// Requests an out-of-band sample (power state change, memory pressure).
    private func refreshSoon() {
        workQueue.async { [weak self] in
            guard let self, !self.suspended else { return }
            self.tick()
        }
    }
}
