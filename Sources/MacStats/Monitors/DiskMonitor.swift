import Foundation
import IOKit
import Darwin.Mach

final class DiskMonitor {
    private var previousRead: UInt64 = 0
    private var previousWrite: UInt64 = 0
    private var previousTimestamp: TimeInterval = 0
    private var baselineRead: UInt64 = 0
    private var baselineWrite: UInt64 = 0
    private var isPrimed = false

    func read() -> DiskStats {
        var stats = readCapacity()

        let (read, write) = blockStorageTotals()
        let now = ProcessInfo.processInfo.systemUptime

        if previousTimestamp > 0 {
            let dt = now - previousTimestamp
            if dt > 0 {
                if read >= previousRead {
                    stats.readBytesPerSec = Double(read - previousRead) / dt
                }
                if write >= previousWrite {
                    stats.writeBytesPerSec = Double(write - previousWrite) / dt
                }
            }
        }

        if !isPrimed {
            baselineRead = read
            baselineWrite = write
            isPrimed = true
        }

        stats.sessionReadBytes = read >= baselineRead ? read - baselineRead : 0
        stats.sessionWriteBytes = write >= baselineWrite ? write - baselineWrite : 0

        previousRead = read
        previousWrite = write
        previousTimestamp = now

        return stats
    }

    private func readCapacity() -> DiskStats {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? NSNumber)?.uint64Value ?? 0
            let free = (attrs[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
            return DiskStats(totalBytes: total, freeBytes: free)
        } catch {
            return DiskStats()
        }
    }

    /// Sums the driver-level byte counters of every physical block storage driver.
    /// IOBlockStorageDriver sits below the volume/APFS layers, so summing across
    /// instances reflects real device traffic without double counting volumes.
    private func blockStorageTotals() -> (read: UInt64, write: UInt64) {
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else { return (0, 0) }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            var propsRef: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let props = propsRef?.takeRetainedValue() as? [String: Any],
               let statistics = props["Statistics"] as? [String: Any] {
                totalRead += (statistics["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                totalWrite += (statistics["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return (totalRead, totalWrite)
    }
}
