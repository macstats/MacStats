import Foundation
import IOKit
import Darwin.Mach

/// Reads GPU utilization / memory from IOKit `IOAccelerator` services.
///
/// `PerformanceStatistics` is an undocumented but stable driver dictionary.
/// Key names differ between Apple Silicon (unified memory) and Intel (VRAM),
/// so every field is probed with a list of candidate keys and degrades to 0.
final class GPUMonitor {
    func read() -> GPUStats {
        var best: GPUStats?

        guard let matching = IOServiceMatching("IOAccelerator") else { return GPUStats() }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return GPUStats()
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            if let candidate = readAccelerator(service),
               candidate.utilizationPercent >= (best?.utilizationPercent ?? -1) {
                best = candidate
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        return best ?? GPUStats()
    }

    // MARK: - Private

    private func readAccelerator(_ service: io_service_t) -> GPUStats? {
        guard let props = copyProperties(service),
              let perf = props["PerformanceStatistics"] as? [String: Any] else {
            return nil
        }

        var stats = GPUStats()
        stats.isAvailable = true
        stats.utilizationPercent = firstDouble(in: perf, keys: [
            "Device Utilization %",
            "GPU Activity(%)",
            "GPU Core Utilization",
        ]) ?? 0

        let used = firstUInt64(in: perf, keys: [
            "In use system memory",
            "vramUsedBytes",
            "In use vid memory",
        ]) ?? 0
        let free = firstUInt64(in: perf, keys: [
            "vramFreeBytes",
            "vramFree",
        ]) ?? 0
        let total = firstUInt64(in: perf, keys: [
            "vramTotalBytes",
            "Recommended Max Working Set Size",
        ]) ?? 0

        stats.memoryUsedBytes = used
        let derivedTotal = total > 0 ? total : (used + free)
        stats.memoryTotalBytes = max(derivedTotal, used)
        stats.coreCount = Int(firstDouble(in: perf, keys: ["gpuCoreCount", "NumLogicalCores"]) ?? 0)
        stats.name = acceleratorName(service, props: props)

        return stats
    }

    private func acceleratorName(_ service: io_service_t, props: [String: Any]) -> String {
        for key in ["model", "IOName"] {
            if let value = props[key] as? String, !value.isEmpty {
                return value
            }
        }

        var parent: io_registry_entry_t = 0
        if IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS {
            defer { IOObjectRelease(parent) }
            if let parentProps = copyProperties(parent) {
                for key in ["model", "IOName"] {
                    if let value = parentProps[key] as? String, !value.isEmpty {
                        return value
                    }
                }
            }
        }

        return (props["IOClass"] as? String) ?? "GPU"
    }

    private func copyProperties(_ service: io_registry_entry_t) -> [String: Any]? {
        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let props = propsRef?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return props
    }

    private func firstDouble(in dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let number = dict[key] as? NSNumber { return number.doubleValue }
        }
        return nil
    }

    private func firstUInt64(in dict: [String: Any], keys: [String]) -> UInt64? {
        for key in keys {
            if let number = dict[key] as? NSNumber { return number.uint64Value }
        }
        return nil
    }
}
