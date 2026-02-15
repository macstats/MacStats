import Foundation
import Darwin

final class ProcessMonitor {
    private var previousCPUTimes: [pid_t: Double] = [:]
    private var previousTimestamp: Double = 0
    private let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)

    func top(_ count: Int = 5) -> [TopProcess] {
        var bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(bufferSize) / MemoryLayout<pid_t>.stride)
        bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferSize)
        let pidCount = Int(bufferSize) / MemoryLayout<pid_t>.stride

        let now = ProcessInfo.processInfo.systemUptime
        let dt = previousTimestamp > 0 ? (now - previousTimestamp) : 0
        let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)

        struct ProcEntry {
            var pid: pid_t
            var name: String
            var cpuPercent: Double
            var memPercent: Double
        }

        var currentCPUTimes: [pid_t: Double] = [:]
        currentCPUTimes.reserveCapacity(pidCount)
        var entries: [ProcEntry] = []
        entries.reserveCapacity(min(pidCount, 300))

        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var taskInfo = proc_taskinfo()
            let infoSize = Int32(MemoryLayout<proc_taskinfo>.stride)
            let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, infoSize)
            guard ret == infoSize else { continue }

            let cpuTime = Double(taskInfo.pti_total_user + taskInfo.pti_total_system) / 1_000_000_000.0
            currentCPUTimes[pid] = cpuTime

            var cpuPercent = 0.0
            if dt > 0, let prevTime = previousCPUTimes[pid] {
                let delta = cpuTime - prevTime
                if delta >= 0 {
                    cpuPercent = (delta / dt) * 100.0 / coreCount
                }
            }

            let memPercent = Double(taskInfo.pti_resident_size) / totalMemory * 100.0

            // Skip idle processes early
            guard cpuPercent > 0.01 || memPercent > 0.1 else { continue }

            var nameBuffer = [CChar](repeating: 0, count: 256)
            let nameLen = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name: String
            if nameLen > 0 {
                name = String(cString: nameBuffer)
            } else {
                continue
            }

            entries.append(ProcEntry(pid: pid, name: name, cpuPercent: cpuPercent, memPercent: memPercent))
        }

        previousCPUTimes = currentCPUTimes
        previousTimestamp = now

        entries.sort { $0.cpuPercent > $1.cpuPercent }

        return entries.prefix(count).map {
            TopProcess(pid: $0.pid, name: $0.name, cpuPercent: $0.cpuPercent, memPercent: $0.memPercent)
        }
    }
}
