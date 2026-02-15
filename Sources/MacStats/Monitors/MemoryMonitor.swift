import Foundation
import Darwin.Mach

final class MemoryMonitor {
    private let hostPort: host_t = mach_host_self()
    private let totalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    private let pageSize: UInt64 = UInt64(vm_kernel_page_size)

    func read() -> MemoryStats {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(
                    hostPort,
                    HOST_VM_INFO64,
                    intPtr,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryStats(totalBytes: totalBytes)
        }

        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        let used = active + wired + compressed

        return MemoryStats(
            totalBytes: totalBytes,
            usedBytes: used,
            activeBytes: active,
            wiredBytes: wired,
            compressedBytes: compressed,
            freeBytes: free
        )
    }
}
