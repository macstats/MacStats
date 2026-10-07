import Darwin
import Foundation
import IOKit

/// Disk capacity via the `statfs` syscall.
///
/// The previous implementation used `FileManager.attributesOfFileSystem`,
/// which builds an attribute dictionary and bridges two `NSNumber`s on every
/// read — measurable spikes every few seconds. `statfs` is one syscall into a
/// stack-allocated struct. The volume name is resolved once at init because
/// it never changes.
///
/// Throughput comes from `IOBlockStorageDriver` statistics, which sit below the
/// volume/APFS layers and therefore reflect real device traffic.
final class DiskMonitor {
    private let volumeName: String
    private var previousRead: UInt64 = 0
    private var previousWrite: UInt64 = 0
    private var previousTimestamp: TimeInterval = 0
    private var baselineRead: UInt64 = 0
    private var baselineWrite: UInt64 = 0
    private var isPrimed = false

    init() {
        let url = URL(fileURLWithPath: "/")
        volumeName = (try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName) ?? "Macintosh HD"
    }

    func read() -> DiskStats {
        var fs = statfs()
        guard statfs("/", &fs) == 0 else { return DiskStats(volumeName: volumeName) }

        let blockSize = UInt64(fs.f_bsize)
        let total = blockSize * UInt64(fs.f_blocks)
        // `f_bavail` excludes reserved blocks, matching Finder's "available".
        let free = blockSize * UInt64(fs.f_bavail)

        var stats = DiskStats(totalBytes: total, freeBytes: free, volumeName: volumeName)

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

    /// Sums the driver-level byte counters of every physical block storage driver.
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
