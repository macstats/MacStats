import Darwin.Mach
import Foundation

/// Reads per-core CPU load from Mach `host_processor_info`.
///
/// Hot-path notes: the tick buffer and the emitted per-core array are
/// allocated once and reused, so a steady-state read performs no heap
/// allocations and exactly one Mach call.
final class CPUMonitor {
    private let hostPort: host_t = mach_host_self()
    private var previousTicks: [UInt32] = []
    private var perCoreUsage: [Double] = []
    private var hasBaseline = false

    func read() -> CPUStats {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            hostPort,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else {
            return CPUStats()
        }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(MemoryLayout<integer_t>.stride * Int(processorInfoCount))
            )
        }

        let coreCount = Int(processorCount)
        let stride = Int(CPU_STATE_MAX)

        if previousTicks.count != coreCount * stride {
            previousTicks = [UInt32](repeating: 0, count: coreCount * stride)
            hasBaseline = false
        }
        if perCoreUsage.count != coreCount {
            perCoreUsage = [Double](repeating: 0, count: coreCount)
        }

        var totalBusy: UInt64 = 0
        var totalTicks: UInt64 = 0

        for core in 0..<coreCount {
            let base = core * stride
            let user = UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])
            let system = UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])

            if hasBaseline {
                let userDelta = UInt64(user &- previousTicks[base + Int(CPU_STATE_USER)])
                let systemDelta = UInt64(system &- previousTicks[base + Int(CPU_STATE_SYSTEM)])
                let idleDelta = UInt64(idle &- previousTicks[base + Int(CPU_STATE_IDLE)])
                let niceDelta = UInt64(nice &- previousTicks[base + Int(CPU_STATE_NICE)])
                let busy = userDelta &+ systemDelta &+ niceDelta
                let all = busy &+ idleDelta

                perCoreUsage[core] = all > 0 ? Double(busy) / Double(all) * 100.0 : 0
                totalBusy &+= busy
                totalTicks &+= all
            }

            previousTicks[base + Int(CPU_STATE_USER)] = user
            previousTicks[base + Int(CPU_STATE_SYSTEM)] = system
            previousTicks[base + Int(CPU_STATE_IDLE)] = idle
            previousTicks[base + Int(CPU_STATE_NICE)] = nice
        }

        hasBaseline = true

        return CPUStats(
            totalUsage: totalTicks > 0 ? Double(totalBusy) / Double(totalTicks) * 100.0 : 0,
            perCoreUsage: perCoreUsage,
            load: Self.loadAverage()
        )
    }

    /// `getloadavg` is a single cheap syscall; no polling source needed.
    private static func loadAverage() -> LoadAverage {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) == 3 else { return LoadAverage() }
        return LoadAverage(one: loads[0], five: loads[1], fifteen: loads[2])
    }
}
