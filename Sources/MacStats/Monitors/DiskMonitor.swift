import Foundation

final class DiskMonitor {
    func read() -> DiskStats {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? NSNumber)?.uint64Value ?? 0
            let free = (attrs[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
            return DiskStats(totalBytes: total, freeBytes: free)
        } catch {
            return DiskStats()
        }
    }
}
