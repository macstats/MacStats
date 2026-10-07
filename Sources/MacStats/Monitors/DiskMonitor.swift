import Darwin
import Foundation

/// Disk capacity via the `statfs` syscall.
///
/// The previous implementation used `FileManager.attributesOfFileSystem`,
/// which builds an attribute dictionary and bridges two `NSNumber`s on every
/// read — measurable spikes every few seconds. `statfs` is one syscall into a
/// stack-allocated struct. The volume name is resolved once at init because
/// it never changes.
final class DiskMonitor {
    private let volumeName: String

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

        return DiskStats(totalBytes: total, freeBytes: free, volumeName: volumeName)
    }
}
