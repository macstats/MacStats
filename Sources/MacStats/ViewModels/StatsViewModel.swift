import Foundation
import Combine

final class StatsViewModel: ObservableObject {
    // SwiftUI-observed properties — only updated when popover is visible
    @Published var stats = SystemStats()
    @Published var cpuHistory: [Double] = []
    @Published var netUpHistory: [Double] = []
    @Published var netDownHistory: [Double] = []
    @Published var topProcesses: [TopProcess] = []
    @Published var uptime: TimeInterval = 0

    // Lightweight callback for status bar (always fires, no SwiftUI overhead)
    var onStatusBarUpdate: ((SystemStats, [Double]) -> Void)?

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
                    self.topProcesses = self.currentProcesses
                    self.uptime = ProcessInfo.processInfo.systemUptime
                }
            }
        }
    }

    // Raw state (always current, not @Published)
    private(set) var currentStats = SystemStats()
    private var currentCPUHistory: [Double] = []
    private var currentNetUpHistory: [Double] = []
    private var currentNetDownHistory: [Double] = []
    private var currentProcesses: [TopProcess] = []

    private let monitor = SystemMonitor()
    private var timerSource: DispatchSourceTimer?
    private let historyLength = 30
    private var tickCount = 0
    private let workQueue = DispatchQueue(label: "com.macstats.monitor", qos: .utility)

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
            let procs = self.tickCount % 5 == 0 ? self.monitor.topProcesses() : nil
            self.tickCount += 1

            DispatchQueue.main.async {
                // Always update raw state
                self.currentStats = s
                if let procs { self.currentProcesses = procs }
                self.appendRawHistory(s)

                // Always notify status bar (lightweight, no SwiftUI)
                self.onStatusBarUpdate?(s, self.currentCPUHistory)

                // Only push to SwiftUI when popover is visible
                if self.isPopoverVisible {
                    self.stats = s
                    self.cpuHistory = self.currentCPUHistory
                    self.netUpHistory = self.currentNetUpHistory
                    self.netDownHistory = self.currentNetDownHistory
                    if let procs { self.topProcesses = procs }
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
            let procs = self.monitor.topProcesses()

            DispatchQueue.main.async {
                self.currentStats = s
                self.currentProcesses = procs
                self.appendRawHistory(s)
                self.onStatusBarUpdate?(s, self.currentCPUHistory)

                self.stats = s
                self.topProcesses = procs
                self.uptime = ProcessInfo.processInfo.systemUptime
                self.cpuHistory = self.currentCPUHistory
            }
        }
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
    }

    func stop() {
        timerSource?.cancel()
        timerSource = nil
    }

    deinit { stop() }
}
