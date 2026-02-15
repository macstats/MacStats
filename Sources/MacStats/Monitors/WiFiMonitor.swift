import Foundation
import CoreWLAN

final class WiFiMonitor {
    private let client = CWWiFiClient.shared()

    func read() -> WiFiStats {
        guard let iface = client.interface() else {
            return WiFiStats()
        }

        let active = iface.powerOn()
        guard active else {
            return WiFiStats(interfaceName: iface.interfaceName ?? "en0")
        }

        let ifName = iface.interfaceName ?? "en0"
        var stats = WiFiStats()
        stats.isActive = true
        stats.interfaceName = ifName
        stats.ssid = iface.ssid() ?? ""
        stats.rssi = iface.rssiValue()
        stats.channel = iface.wlanChannel()?.channelNumber ?? 0
        stats.localIP = localIPAddress(for: ifName)

        return stats
    }

    private func localIPAddress(for interfaceName: String) -> String {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return "" }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            let addr = ifa.pointee
            cursor = addr.ifa_next

            guard let name = addr.ifa_name, String(cString: name) == interfaceName else { continue }
            guard addr.ifa_addr?.pointee.sa_family == UInt8(AF_INET) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr.ifa_addr, socklen_t(addr.ifa_addr!.pointee.sa_len),
                           &hostname, socklen_t(hostname.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: hostname)
            }
        }
        return ""
    }
}
