import AppKit
import Combine
import SwiftUI

    /// Owns the menu bar item, its text/chart rendering, and the popover.
///
/// Rendering is treated as a hot path: the controller keeps a single-entry
/// text cache, redraws the chart only when a new sample revision arrives, and
/// reuses one bitmap-backed chart renderer per (size, scale, appearance).
final class StatusBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    /// Created on first click: the SwiftUI popover tree costs ~14 MB of
    /// resident memory, and most launches never open it.
    private var popover: NSPopover?
    private let viewModel: StatsViewModel
    private let settings: AppSettings

    private var cancellables = Set<AnyCancellable>()
    private var closeObserver: NSObjectProtocol?

    private var lastRevision: UInt64 = .max
    private var chartRenderer: MenuBarChartRenderer?
    private var cachedTitleKey = ""
    private var cachedTitle: NSAttributedString?

    private let menuBarStyleItem = NSMenuItem(title: "Menu Bar", action: nil, keyEquivalent: "")
    private let refreshRateItem = NSMenuItem(title: "Refresh", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")

    private static let chartSize = NSSize(width: 46, height: 13)
    private static let textFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)

    // Cached symbol attachments (created once, reused for every title).
    private static let cpuIcon = makeIcon("cpu")
    private static let memoryIcon = makeIcon("memorychip")
    private static let upIcon = makeIcon("arrow.up")
    private static let downIcon = makeIcon("arrow.down")

    init(viewModel: StatsViewModel, settings: AppSettings) {
        self.viewModel = viewModel
        self.settings = settings

        statusItem = NSStatusBar.system.statusItem(withLength: 200)

        super.init()

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("MacStats")
        }

        // Status bar updates are a plain callback: no SwiftUI, no Combine.
        viewModel.onStatusBarUpdate = { [weak self] sample in
            self?.render(sample)
        }

        // Re-render whenever presentation settings change.
        settings.$menuBarStyle
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] style in
                guard let self else { return }
                self.statusItem.length = self.length(for: style)
                self.refreshTitle(force: true)
            }
            .store(in: &cancellables)

        render(StatusBarSample(stats: viewModel.latestStats, cpuHistory: [], revision: 0))
    }

    deinit {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
    }

    // MARK: - Rendering

    private func render(_ sample: StatusBarSample) {
        guard let button = statusItem.button else { return }
        guard sample.revision != lastRevision else { return }
        lastRevision = sample.revision
        refreshTitle(force: false, stats: sample.stats)

        let scale = (button.window?.screen ?? NSScreen.main)?.backingScaleFactor ?? 2
        let appearance = button.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua

        if chartRenderer == nil
            || chartRenderer?.matches(size: Self.chartSize, scale: scale, appearance: appearance) == false {
            chartRenderer = MenuBarChartRenderer(size: Self.chartSize, scale: scale, appearance: appearance)
        }

        if let renderer = chartRenderer, !sample.cpuHistory.isEmpty {
            button.image = renderer.image(samples: sample.cpuHistory)
        }

        button.setAccessibilityValue(
            "CPU \(Format.percent(sample.stats.cpu.totalUsage)), "
                + "memory \(Format.percent(sample.stats.memory.usagePercent))"
        )
        button.toolTip = "MacStats — CPU \(Format.percent(sample.stats.cpu.totalUsage, decimals: 1)), "
            + "Memory \(Format.percent(sample.stats.memory.usagePercent, decimals: 1)), "
            + "↓ \(Format.speed(sample.stats.network.bytesReceivedPerSec)) "
            + "↑ \(Format.speed(sample.stats.network.bytesSentPerSec))"
    }

    private func refreshTitle(force: Bool, stats: SystemStats? = nil) {
        let current = stats ?? viewModel.latestStats
        let style = settings.menuBarStyle

        let cpu = String(format: "%2.0f%%", current.cpu.totalUsage)
        let memory = String(format: "%2.0f%%", current.memory.usagePercent)
        let up = Format.menuBarSpeed(current.network.bytesSentPerSec)
        let down = Format.menuBarSpeed(current.network.bytesReceivedPerSec)
        let key = "\(style.rawValue)|\(cpu)|\(memory)|\(up)|\(down)"

        guard force || key != cachedTitleKey else { return }
        cachedTitleKey = key

        let title = NSMutableAttributedString()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.textFont,
            .foregroundColor: NSColor.labelColor,
        ]

        func append(_ string: String) {
            title.append(NSAttributedString(string: string, attributes: attributes))
        }

        append(" ")
        append(cpu)

        switch style {
        case .full:
            append("  ")
            title.append(Self.memoryIcon)
            append(" \(memory)  ")
            title.append(Self.downIcon)
            append(" \(down) ")
            title.append(Self.upIcon)
            append(" \(up)")
        case .compact:
            append("  ")
            title.append(Self.memoryIcon)
            append(" \(memory)")
        case .minimal, .chart:
            break
        }

        cachedTitle = title
        statusItem.button?.attributedTitle = title
    }

    /// Fixed widths per style: the menu bar never reflows as values change.
    private func length(for style: AppSettings.MenuBarStyle) -> CGFloat {
        let chart = Self.chartSize.width + 6
        switch style {
        case .full:
            return chart + Self.width(of: " 100% 100% 999.9M 999.9M") + 14
        case .compact:
            return chart + Self.width(of: " 100% 100%") + 12
        case .minimal:
            return chart + Self.width(of: " 100%") + 10
        case .chart:
            return chart + 10
        }
    }

    private static func width(of string: String) -> CGFloat {
        ceil(
            (string as NSString)
                .size(withAttributes: [.font: textFont])
                .width
        )
    }

    private static func makeIcon(_ name: String) -> NSAttributedString {
        let configuration = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            return NSAttributedString(string: "")
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -1, width: 11, height: 11)
        return NSAttributedString(attachment: attachment)
    }

    // MARK: - Click handling

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: AnyObject?) {
        if let popover, popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let button = statusItem.button else { return }

        let popover = self.popover ?? makePopover()
        viewModel.isPopoverVisible = true
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePopover() -> NSPopover {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: DS.Layout.popoverWidth, height: 600)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(viewModel: viewModel, settings: settings)
        )
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification,
            object: popover,
            queue: .main
        ) { [weak self] _ in
            self?.viewModel.isPopoverVisible = false
        }
        self.popover = popover
        return popover
    }

    // MARK: - Context menu

    private func showContextMenu() {
        let menu = NSMenu()
        menu.delegate = self

        menu.addItem(menuItem("Open Activity Monitor", symbol: "gauge.with.dots.needle.33percent", action: #selector(openActivityMonitor)))
        menu.addItem(menuItem("Copy Stats Summary", symbol: "doc.on.clipboard", action: #selector(copyStatsSummary)))
        menu.addItem(menuItem("Export Metrics CSV…", symbol: "square.and.arrow.down", action: #selector(exportMetricsCSV)))
        menu.addItem(.separator())

        let quickActions = NSMenu()
        quickActions.addItem(menuItem("Sleep Display", symbol: "moon.fill", action: #selector(sleepDisplay)))
        quickActions.addItem(menuItem("Toggle Dark Mode", symbol: "circle.lefthalf.filled", action: #selector(toggleDarkMode)))
        quickActions.addItem(menuItem("Restart Finder", symbol: "arrow.clockwise", action: #selector(restartFinder)))
        let quickActionsItem = menuItem("Quick Actions", symbol: "bolt.fill", action: nil)
        quickActionsItem.submenu = quickActions
        menu.addItem(quickActionsItem)

        let alerts = NSMenu()
        let alertsToggle = menuItem("Enable Alerts", action: #selector(toggleAlerts(_:)))
        alertsToggle.state = viewModel.alertsEnabled ? .on : .off
        alerts.addItem(alertsToggle)
        alerts.addItem(menuItem("Send Test Notification", symbol: "bell.badge", action: #selector(sendTestNotification)))
        let alertsItem = menuItem("Alerts", symbol: "bell", action: nil)
        alertsItem.submenu = alerts
        menu.addItem(alertsItem)

        menu.addItem(.separator())

        menuBarStyleItem.submenu = buildMenuBarStyleMenu()
        menuBarStyleItem.image = symbolImage("menubar.rectangle")
        menu.addItem(menuBarStyleItem)

        refreshRateItem.submenu = buildRefreshRateMenu()
        refreshRateItem.image = symbolImage("arrow.clockwise.circle")
        menu.addItem(refreshRateItem)

        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.image = symbolImage("person.crop.circle.badge.checkmark")
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())
        let quit = menuItem("Quit MacStats", symbol: "power", action: #selector(quitApp))
        quit.keyEquivalent = "q"
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginItem.state = AppActions.isLaunchAtLoginEnabled ? .on : .off

        for item in menuBarStyleItem.submenu?.items ?? [] {
            item.state = item.representedObject as? String == settings.menuBarStyle.rawValue ? .on : .off
        }
        for item in refreshRateItem.submenu?.items ?? [] {
            let seconds = item.representedObject as? Double
            item.state = seconds == settings.refreshRate.seconds ? .on : .off
        }
    }

    private func buildMenuBarStyleMenu() -> NSMenu {
        let menu = NSMenu()
        for style in AppSettings.MenuBarStyle.allCases {
            let item = menuItem(style.label, action: #selector(selectMenuBarStyle(_:)))
            item.representedObject = style.rawValue
            menu.addItem(item)
        }
        return menu
    }

    private func buildRefreshRateMenu() -> NSMenu {
        let menu = NSMenu()
        for rate in AppSettings.RefreshRate.allCases {
            let item = menuItem(rate.label, action: #selector(selectRefreshRate(_:)))
            item.representedObject = rate.seconds
            menu.addItem(item)
        }
        return menu
    }

    private func menuItem(_ title: String, symbol: String? = nil, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let symbol {
            item.image = symbolImage(symbol)
        }
        return item
    }

    private func symbolImage(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    // MARK: - Actions

    @objc private func openActivityMonitor() { AppActions.openActivityMonitor() }

    @objc private func copyStatsSummary() { AppActions.copySummary(viewModel.latestStats) }

    @objc private func exportMetricsCSV() {
        AppActions.saveCSV(
            viewModel.csvSnapshot(),
            suggestedName: MetricsExporter.suggestedFileName()
        )
    }

    @objc private func toggleAlerts(_ sender: NSMenuItem) {
        viewModel.setAlertsEnabled(!viewModel.alertsEnabled)
        sender.state = viewModel.alertsEnabled ? .on : .off
    }

    @objc private func sendTestNotification() {
        viewModel.sendTestNotification()
    }

    @objc private func sleepDisplay() { AppActions.sleepDisplay() }

    @objc private func toggleDarkMode() { AppActions.toggleDarkMode() }

    @objc private func restartFinder() { AppActions.restartFinder() }

    @objc private func toggleLaunchAtLogin() { AppActions.toggleLaunchAtLogin() }

    @objc private func selectMenuBarStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = AppSettings.MenuBarStyle(rawValue: raw) else { return }
        settings.menuBarStyle = style
    }

    @objc private func selectRefreshRate(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Double,
              let rate = AppSettings.RefreshRate(rawValue: seconds) else { return }
        settings.refreshRate = rate
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
