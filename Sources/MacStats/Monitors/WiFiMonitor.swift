import CoreWLAN
import Darwin
import Foundation

/// Wi-Fi state via CoreWLAN, refreshed on a slow cadence.
///
/// `CWWiFiClient` calls are comparatively expensive, so this monitor assumes
/// it is called rarely (see `SystemMonitor`'s backoff) and resolves the local
/// IP with byte comparisons rather than bridging a `String` per interface.
final class WiFiMonitor {
    private let client = CWWiFiClient.shared()
    private var cached = WiFiStats()
    private var readCount = 0
    /// `CWInterface.rssiValue()` costs ~3.5 ms on macOS 26 — roughly 15x every
    /// other CoreWLAN call — so signal strength is sampled every other pass,
    /// while SSID/channel/IP (each ~0.25 ms) every sixth. Everything else is
    /// served from the cache.
    private let signalInterval = 2
    private let identityInterval = 6

    func invalidate() {
        readCount = 0
        cached = WiFiStats()
    }

    func read() -> WiFiStats {
        guard let iface = client.interface() else {
            cached = WiFiStats()
            return cached
        }

        let interfaceName = iface.interfaceName ?? "en0"
        guard iface.powerOn() else {
            cached = WiFiStats(interfaceName: interfaceName)
            return cached
        }

        // Note: an empty SSID must not force a full read on every call —
        // without Location permission `ssid()` stays empty, which would
        // otherwise make the "fast" path as expensive as the slow one.
        let needsSignal = readCount % signalInterval == 1 || readCount == 0
        let needsIdentity = readCount % identityInterval == 0
        readCount &+= 1

        var stats = needsIdentity ? WiFiStats() : cached
        stats.isActive = true
        stats.interfaceName = interfaceName

        if needsSignal {
            stats.rssi = iface.rssiValue()
            stats.transmitRateMbps = iface.transmitRate()
        }
        if needsIdentity {
            stats.ssid = iface.ssid() ?? ""
            stats.channel = iface.wlanChannel()?.channelNumber ?? 0
            stats.localIP = localIPAddress(for: interfaceName)
        }

        cached = stats
        return stats
    }

    private func localIPAddress(for interfaceName: String) -> String {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return "" }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            let entry = ifa.pointee
            cursor = entry.ifa_next

            guard let addr = entry.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            guard let name = entry.ifa_name else { continue }
            guard interfaceName.withCString({ strcmp($0, name) == 0 }) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                return String(cString: hostname)
            }
        }
        return ""
    }
}
