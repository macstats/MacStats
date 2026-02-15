import AppKit
import SwiftUI
import Combine
import ServiceManagement

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private weak var viewModel: StatsViewModel?
    private var closeObserver: Any?

    // Cached icon attributed strings (created once, reused forever)
    private static let cpuIcon = makeIcon("cpu")
    private static let memIcon = makeIcon("memorychip")
    private static let upIcon = makeIcon("arrow.up")
    private static let downIcon = makeIcon("arrow.down")

    // Cache previous formatted values to skip redundant renders
    private var prevCPU: String = ""
    private var prevMem: String = ""
    private var prevUp: String = ""
    private var prevDown: String = ""

    private static let textFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
    private static let iconSize: CGFloat = 12
    private static let chartWidth: CGFloat = 46
    private static let chartHeight: CGFloat = 13

    init(viewModel: StatsViewModel) {
        self.viewModel = viewModel

        // Measure max text width for fixed sizing
        let maxText = StatusBarController.buildAttributed(
            cpu: "100", mem: "100", up: "99.9M", down: "99.9M"
        )
        let textWidth = ceil(maxText.size().width)
        let fixedLen = Self.chartWidth + 6 + textWidth + 16

        statusItem = NSStatusBar.system.statusItem(withLength: fixedLen)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 580)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(viewModel: viewModel)
        )

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Use lightweight callback instead of Combine/$stats subscription
        viewModel.onStatusBarUpdate = { [weak self] stats, history in
            self?.updateStatusBar(stats, history: history)
        }

        // Track ALL popover close events (transient dismiss, performClose, etc.)
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification,
            object: popover,
            queue: .main
        ) { [weak self] _ in
            self?.viewModel?.isPopoverVisible = false
        }
    }

    deinit {
        if let obs = closeObserver { NotificationCenter.default.removeObserver(obs) }
    }

    // MARK: - Status Bar Render (only when values change)

    private func updateStatusBar(_ stats: SystemStats, history: [Double]) {
        guard let button = statusItem.button else { return }

        let cpu = String(format: "%3.0f", stats.cpu.totalUsage)
        let mem = String(format: "%3.0f", stats.memory.usagePercent)
        let up = Self.formatSpeed(stats.network.bytesSentPerSec)
        let down = Self.formatSpeed(stats.network.bytesReceivedPerSec)

        // Only rebuild attributed string when text actually changes
        if cpu != prevCPU || mem != prevMem || up != prevUp || down != prevDown {
            prevCPU = cpu; prevMem = mem; prevUp = up; prevDown = down
            button.attributedTitle = Self.buildAttributed(cpu: cpu, mem: mem, up: up, down: down)
        }

        // Bar chart always needs redraw (new data point shifts history)
        button.image = Self.renderBarChart(history: history)
    }

    // MARK: - Mini bar chart

    private static func renderBarChart(history: [Double]) -> NSImage {
        let w = chartWidth
        let h = chartHeight
        let barW: CGFloat = 2
        let gap: CGFloat = 1
        let maxBars = Int(w / (barW + gap))
        let samples = Array(history.suffix(maxBars))

        let image = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            ctx.setFillColor(NSColor.quaternaryLabelColor.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

            for (i, value) in samples.enumerated() {
                let fraction = CGFloat(min(max(value / 100.0, 0), 1))
                let barH = max(fraction * h, 0.5)
                let x = CGFloat(i) * (barW + gap)
                ctx.setFillColor(barColor(fraction))
                ctx.fill(CGRect(x: x, y: 0, width: barW, height: barH))
            }

            return true
        }
        image.isTemplate = false
        return image
    }

    private static func barColor(_ fraction: CGFloat) -> CGColor {
        if fraction > 0.8 {
            return NSColor.systemRed.cgColor
        } else if fraction > 0.5 {
            return NSColor.systemOrange.cgColor
        } else {
            return NSColor.systemCyan.cgColor
        }
    }

    // MARK: - Text (uses cached icon images)

    private static func buildAttributed(
        cpu: String, mem: String, up: String, down: String
    ) -> NSAttributedString {
        let str = NSMutableAttributedString()
        let attrs: [NSAttributedString.Key: Any] = [.font: textFont]

        str.append(NSAttributedString(string: " ", attributes: attrs))
        str.append(cpuIcon)
        str.append(NSAttributedString(string: "\(cpu)%  ", attributes: attrs))
        str.append(memIcon)
        str.append(NSAttributedString(string: "\(mem)%  ", attributes: attrs))
        str.append(upIcon)
        str.append(NSAttributedString(string: "\(up) ", attributes: attrs))
        str.append(downIcon)
        str.append(NSAttributedString(string: down, attributes: attrs))

        return str
    }

    private static func makeIcon(_ name: String) -> NSAttributedString {
        let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else {
            return NSAttributedString(string: " ")
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -1, width: iconSize, height: iconSize)
        return NSAttributedString(attachment: attachment)
    }

    private static func formatSpeed(_ bps: Double) -> String {
        if bps < 1024 {
            return String(format: "%4.0fB", bps)
        } else if bps < 1024 * 1024 {
            let k = bps / 1024
            return k < 10 ? String(format: "%3.1fK", k) : String(format: "%4.0fK", k)
        } else if bps < 1024 * 1024 * 1024 {
            let m = bps / (1024 * 1024)
            return m < 10 ? String(format: "%3.1fM", m) : String(format: "%4.0fM", m)
        } else {
            return String(format: "%3.1fG", bps / (1024 * 1024 * 1024))
        }
    }

    // MARK: - Status Item Click (Left = Popover, Right = Menu)

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    // MARK: - Popover

    private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
            // didCloseNotification handles isPopoverVisible = false
        } else if let button = statusItem.button {
            viewModel?.isPopoverVisible = true
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Right-click Context Menu

    private func showContextMenu() {
        let menu = NSMenu()

        let activityItem = NSMenuItem(
            title: "Open Activity Monitor",
            action: #selector(openActivityMonitor),
            keyEquivalent: ""
        )
        activityItem.target = self
        activityItem.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent",
                                     accessibilityDescription: nil)
        menu.addItem(activityItem)

        let copyItem = NSMenuItem(
            title: "Copy Stats Summary",
            action: #selector(copyStatsSummary),
            keyEquivalent: ""
        )
        copyItem.target = self
        copyItem.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                 accessibilityDescription: nil)
        menu.addItem(copyItem)

        menu.addItem(.separator())

        // Quick Actions submenu
        let actionsMenu = NSMenu()

        let sleepItem = NSMenuItem(
            title: "Sleep Display",
            action: #selector(sleepDisplay),
            keyEquivalent: ""
        )
        sleepItem.target = self
        sleepItem.image = NSImage(systemSymbolName: "moon.fill",
                                  accessibilityDescription: nil)
        actionsMenu.addItem(sleepItem)

        let darkModeItem = NSMenuItem(
            title: "Toggle Dark Mode",
            action: #selector(toggleDarkMode),
            keyEquivalent: ""
        )
        darkModeItem.target = self
        darkModeItem.image = NSImage(systemSymbolName: "circle.lefthalf.filled",
                                     accessibilityDescription: nil)
        actionsMenu.addItem(darkModeItem)

        let finderItem = NSMenuItem(
            title: "Restart Finder",
            action: #selector(restartFinder),
            keyEquivalent: ""
        )
        finderItem.target = self
        finderItem.image = NSImage(systemSymbolName: "arrow.clockwise",
                                   accessibilityDescription: nil)
        actionsMenu.addItem(finderItem)

        let quickActionsItem = NSMenuItem(
            title: "Quick Actions",
            action: nil,
            keyEquivalent: ""
        )
        quickActionsItem.submenu = actionsMenu
        quickActionsItem.image = NSImage(systemSymbolName: "bolt.fill",
                                         accessibilityDescription: nil)
        menu.addItem(quickActionsItem)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.image = NSImage(systemSymbolName: "person.crop.circle.badge.checkmark",
                                   accessibilityDescription: nil)
        if SMAppService.mainApp.status == .enabled {
            launchItem.state = .on
        }
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit MacStats",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power",
                                 accessibilityDescription: nil)
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }

    @objc private func copyStatsSummary() {
        guard let vm = viewModel else { return }
        let s = vm.currentStats

        var lines: [String] = []
        lines.append("MacStats Summary")
        lines.append("CPU: \(String(format: "%.1f%%", s.cpu.totalUsage)) (\(s.cpu.coreCount) cores)")
        lines.append("Memory: \(String(format: "%.1f%%", s.memory.usagePercent)) (\(formatBytes(s.memory.usedBytes)) / \(formatBytes(s.memory.totalBytes)))")
        lines.append("Network: ↑\(Self.formatSpeed(s.network.bytesSentPerSec))/s  ↓\(Self.formatSpeed(s.network.bytesReceivedPerSec))/s")
        lines.append("Disk: \(String(format: "%.1f%%", s.disk.usagePercent)) (\(formatBytes(s.disk.usedBytes)) / \(formatBytes(s.disk.totalBytes)))")

        if s.battery.isPresent {
            var bat = "Battery: \(String(format: "%.0f%%", s.battery.chargePercent))"
            if s.battery.isCharging { bat += " (Charging)" }
            else if s.battery.isPluggedIn { bat += " (Plugged In)" }
            lines.append(bat)
        }

        let text = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {}
    }

    @objc private func sleepDisplay() {
        // Use IOKit to sleep the display without root privileges
        let port = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IODisplayWrangler"))
        if port != IO_OBJECT_NULL {
            IORegistryEntrySetCFProperty(port, "IORequestIdle" as CFString, true as CFBoolean)
            IOObjectRelease(port)
        }
    }

    @objc private func toggleDarkMode() {
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
            end tell
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    @objc private func restartFinder() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Finder"]
        try? task.run()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }
}
