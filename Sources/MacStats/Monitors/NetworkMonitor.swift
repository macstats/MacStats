import Darwin
import Foundation

/// Interface counters via `getifaddrs`.
///
/// Hot-path notes: the interface name is compared as raw C bytes instead of
/// bridging every interface to a Swift `String`, which removes ~20 string
/// allocations per sample on a typical Mac. Session totals are accumulated
/// here so the UI never has to diff counters itself.
final class NetworkMonitor {
    private var previousBytesSent: UInt64 = 0
    private var previousBytesReceived: UInt64 = 0
    private var previousTimestamp: TimeInterval = 0
    private var sessionSent: UInt64 = 0
    private var sessionReceived: UInt64 = 0
    private var peakSentPerSec: Double = 0
    private var peakReceivedPerSec: Double = 0

    private static let loopbackName = "lo0"

    func read() -> NetworkStats {
        var totalSent: UInt64 = 0
        var totalReceived: UInt64 = 0

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else {
            return NetworkStats()
        }
        defer { freeifaddrs(ifaddrPtr) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            let entry = ifa.pointee
            cursor = entry.ifa_next

            // Family check first: cheapest possible rejection.
            guard let addr = entry.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            guard let name = entry.ifa_name else { continue }
            if strcmp(name, Self.loopbackName) == 0 { continue }
            guard let data = entry.ifa_data else { continue }

            let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
            totalSent &+= UInt64(interfaceData.ifi_obytes)
            totalReceived &+= UInt64(interfaceData.ifi_ibytes)
        }

        let now = ProcessInfo.processInfo.systemUptime

        var sentPerSec = 0.0
        var receivedPerSec = 0.0

        if previousTimestamp > 0 {
            let dt = now - previousTimestamp
            if dt > 0 {
                let sentDelta = totalSent >= previousBytesSent ? totalSent - previousBytesSent : 0
                let receivedDelta = totalReceived >= previousBytesReceived ? totalReceived - previousBytesReceived : 0
                sentPerSec = Double(sentDelta) / dt
                receivedPerSec = Double(receivedDelta) / dt
                sessionSent &+= sentDelta
                sessionReceived &+= receivedDelta
            }
        }

        previousBytesSent = totalSent
        previousBytesReceived = totalReceived
        previousTimestamp = now

        peakSentPerSec = max(peakSentPerSec, sentPerSec)
        peakReceivedPerSec = max(peakReceivedPerSec, receivedPerSec)

        return NetworkStats(
            bytesSentPerSec: sentPerSec,
            bytesReceivedPerSec: receivedPerSec,
            sessionSentBytes: sessionSent,
            sessionReceivedBytes: sessionReceived,
            peakSentPerSec: peakSentPerSec,
            peakReceivedPerSec: peakReceivedPerSec
        )
    }
}
