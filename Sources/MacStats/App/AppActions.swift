import AppKit
import Foundation
import IOKit
import ServiceManagement

/// Desktop actions shared by the popover menu and the status item's
/// contextual menu, so no view or controller owns its own copy.
enum AppActions {

    static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }

    /// Presents a save panel and writes `csv` to the chosen location.
    static func saveCSV(_ csv: String, suggestedName: String) {
        let panel = NSSavePanel()
        panel.title = "Export MacStats session metrics"
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
        }
    }

    static func copySummary(_ stats: SystemStats) {
        var lines: [String] = ["MacStats Summary"]
        lines.append("CPU: \(Format.percent(stats.cpu.totalUsage, decimals: 1)) (\(stats.cpu.coreCount) cores)")
        lines.append(
            "Memory: \(Format.percent(stats.memory.usagePercent, decimals: 1)) "
                + "(\(Format.bytes(stats.memory.usedBytes)) / \(Format.bytes(stats.memory.totalBytes)))"
        )
        lines.append(
            "Network: ↑\(Format.speed(stats.network.bytesSentPerSec)) ↓\(Format.speed(stats.network.bytesReceivedPerSec))"
        )
        lines.append(
            "Disk: \(Format.percent(stats.disk.usagePercent, decimals: 1)) "
                + "(\(Format.bytes(stats.disk.usedBytes)) / \(Format.bytes(stats.disk.totalBytes)))"
        )
        lines.append(
            "Disk I/O: read \(Format.speed(stats.disk.readBytesPerSec)) write \(Format.speed(stats.disk.writeBytesPerSec))"
        )
        if stats.gpu.isAvailable {
            var gpu = "GPU: \(Format.percent(stats.gpu.utilizationPercent, decimals: 1))"
            if !stats.gpu.name.isEmpty { gpu += " (\(stats.gpu.name))" }
            if stats.gpu.memoryTotalBytes > 0 {
                gpu += " mem \(Format.bytes(stats.gpu.memoryUsedBytes)) / \(Format.bytes(stats.gpu.memoryTotalBytes))"
            }
            lines.append(gpu)
        }
        if stats.sensors.isAvailable {
            var sensors: [String] = []
            if let temperature = stats.sensors.cpuTemperature {
                sensors.append(String(format: "CPU %.1f°C", temperature))
            }
            for fan in stats.sensors.fans {
                sensors.append("Fan \(fan.index) \(fan.rpm) RPM")
            }
            if !sensors.isEmpty {
                lines.append("Thermals: " + sensors.joined(separator: "  "))
            }
        }
        if stats.connections.isAvailable {
            lines.append(
                "TCP: \(stats.connections.established) established, "
                    + "\(stats.connections.listening) listening, \(stats.connections.total) total"
            )
        }
        if stats.battery.isPresent {
            var battery = "Battery: \(Format.percent(stats.battery.chargePercent))"
            if stats.battery.isCharging { battery += " (Charging)" }
            else if stats.battery.isPluggedIn { battery += " (Plugged In)" }
            lines.append(battery)
        }
        if stats.wifi.isActive, !stats.wifi.ssid.isEmpty {
            lines.append("Wi-Fi: \(stats.wifi.ssid) (\(stats.wifi.rssi) dBm)")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
    }

    static func sleepDisplay() {
        let port = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IODisplayWrangler"))
        guard port != IO_OBJECT_NULL else { return }
        IORegistryEntrySetCFProperty(port, "IORequestIdle" as CFString, true as CFBoolean)
        IOObjectRelease(port)
    }

    static func toggleDarkMode() {
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

    static func restartFinder() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Finder"]
        try? task.run()
    }

    static var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            // Registration can fail when the app is not in /Applications;
            // the menu state simply stays unchanged.
        }
    }
}
