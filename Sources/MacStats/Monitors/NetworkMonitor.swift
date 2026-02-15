import Foundation
import Darwin

final class NetworkMonitor {
    private var previousBytesSent: UInt64 = 0
    private var previousBytesReceived: UInt64 = 0
    private var previousTimestamp: TimeInterval = 0

    func read() -> NetworkStats {
        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
            return NetworkStats()
        }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let ifa = cursor {
            let addr = ifa.pointee
            cursor = addr.ifa_next

            guard let name = addr.ifa_name else { continue }
            let ifName = String(cString: name)
            if ifName == "lo0" { continue }

            guard addr.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else { continue }

            addr.ifa_data.withMemoryRebound(to: if_data.self, capacity: 1) { data in
                totalSent += UInt64(data.pointee.ifi_obytes)
                totalReceived += UInt64(data.pointee.ifi_ibytes)
            }
        }

        let now = ProcessInfo.processInfo.systemUptime

        var sentPerSec: Double = 0
        var receivedPerSec: Double = 0

        if previousTimestamp > 0 {
            let dt = now - previousTimestamp
            if dt > 0 {
                let sentDelta = totalSent >= previousBytesSent
                    ? totalSent - previousBytesSent : 0
                let receivedDelta = totalReceived >= previousBytesReceived
                    ? totalReceived - previousBytesReceived : 0
                sentPerSec = Double(sentDelta) / dt
                receivedPerSec = Double(receivedDelta) / dt
            }
        }

        previousBytesSent = totalSent
        previousBytesReceived = totalReceived
        previousTimestamp = now

        return NetworkStats(bytesSentPerSec: sentPerSec, bytesReceivedPerSec: receivedPerSec)
    }
}
