import Foundation
import Darwin.Mach

final class CPUMonitor {
    private var previousTicks: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []
    private let hostPort: host_t = mach_host_self()

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
            let size = vm_size_t(
                MemoryLayout<integer_t>.stride * Int(processorInfoCount)
            )
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let coreCount = Int(processorCount)
        var currentTicks: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)] = []
        currentTicks.reserveCapacity(coreCount)
        var perCoreUsage: [Double] = []
        perCoreUsage.reserveCapacity(coreCount)
        var totalUserDelta: UInt64 = 0
        var totalSystemDelta: UInt64 = 0
        var totalIdleDelta: UInt64 = 0

        for i in 0..<coreCount {
            let offset = Int(CPU_STATE_MAX) * i
            let user = UInt32(bitPattern: info[offset + Int(CPU_STATE_USER)])
            let system = UInt32(bitPattern: info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(bitPattern: info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt32(bitPattern: info[offset + Int(CPU_STATE_NICE)])

            currentTicks.append((user: user, system: system, idle: idle, nice: nice))

            if i < previousTicks.count {
                let prev = previousTicks[i]
                let userDelta = UInt64(user &- prev.user)
                let systemDelta = UInt64(system &- prev.system)
                let idleDelta = UInt64(idle &- prev.idle)
                let niceDelta = UInt64(nice &- prev.nice)
                let total = userDelta + systemDelta + idleDelta + niceDelta

                if total > 0 {
                    let usage = Double(userDelta + systemDelta + niceDelta) / Double(total) * 100.0
                    perCoreUsage.append(usage)
                } else {
                    perCoreUsage.append(0)
                }

                totalUserDelta += userDelta + niceDelta
                totalSystemDelta += systemDelta
                totalIdleDelta += idleDelta
            } else {
                perCoreUsage.append(0)
            }
        }

        previousTicks = currentTicks

        let grandTotal = totalUserDelta + totalSystemDelta + totalIdleDelta
        let totalUsage: Double
        if grandTotal > 0 {
            totalUsage = Double(totalUserDelta + totalSystemDelta) / Double(grandTotal) * 100.0
        } else {
            totalUsage = 0
        }

        return CPUStats(totalUsage: totalUsage, perCoreUsage: perCoreUsage)
    }
}
