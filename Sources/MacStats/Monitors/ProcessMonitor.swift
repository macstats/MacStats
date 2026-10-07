import Darwin
import Foundation

/// Top processes by CPU, ranking with `proc_pidinfo(PROC_PIDTASKINFO)`.
///
/// This is the most expensive monitor in the app (one syscall per running
/// process), so it runs on its own slower cadence and is tuned here: the PID
/// buffer is reused, `proc_taskinfo` stays on the stack, sample dictionaries
/// are double-buffered instead of copied, and process names are only resolved
/// for processes that survive the threshold filter.
final class ProcessMonitor {
    private var previousCPUTimes: [pid_t: Double] = [:]
    private var currentCPUTimes: [pid_t: Double] = [:]
    private var pidBuffer: [pid_t] = []
    private var previousTimestamp: Double = 0
    private let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
    private let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)

    /// Ranks processes by CPU or resident memory, optionally filtered by a
    /// case-insensitive substring match on the name or executable path.
    func top(_ count: Int = 5, sort: ProcessSortKey = .cpu, query: String = "") -> [TopProcess] {
        var bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }

        let requiredCount = Int(bufferSize) / MemoryLayout<pid_t>.stride + 32
        if pidBuffer.count < requiredCount {
            pidBuffer = [pid_t](repeating: 0, count: requiredCount)
        }

        bufferSize = pidBuffer.withUnsafeMutableBytes { raw -> Int32 in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, raw.baseAddress, Int32(raw.count))
        }
        let pidCount = Int(bufferSize) / MemoryLayout<pid_t>.stride
        guard pidCount > 0 else { return [] }

        let now = ProcessInfo.processInfo.systemUptime
        let dt = previousTimestamp > 0 ? now - previousTimestamp : 0
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let isSearching = !needle.isEmpty

        currentCPUTimes.removeAll(keepingCapacity: true)
        currentCPUTimes.reserveCapacity(pidCount)

        var candidates: [TopProcess] = []
        candidates.reserveCapacity(64)

        let infoSize = Int32(MemoryLayout<proc_taskinfo>.stride)

        for index in 0..<pidCount {
            let pid = pidBuffer[index]
            guard pid > 0 else { continue }

            var taskInfo = proc_taskinfo()
            let read = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, infoSize)
            guard read == infoSize else { continue }

            let cpuTime = Double(taskInfo.pti_total_user + taskInfo.pti_total_system) / 1_000_000_000.0
            currentCPUTimes[pid] = cpuTime

            var cpuPercent = 0.0
            if dt > 0, let previous = previousCPUTimes[pid] {
                let delta = cpuTime - previous
                if delta >= 0 {
                    cpuPercent = (delta / dt) * 100.0 / coreCount
                }
            }

            let memPercent = Double(taskInfo.pti_resident_size) / totalMemory * 100.0

            // Cheap rejects happen before any name resolution. Searching and
            // memory ranking need the quiet processes too.
            if !isSearching && sort == .cpu {
                guard cpuPercent > 0.05 || memPercent > 0.2 else { continue }
            }

            var nameBuffer = [CChar](repeating: 0, count: 128)
            let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))

            var executablePath = ""
            if isSearching {
                var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
                if proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 {
                    executablePath = String(cString: pathBuffer)
                }
            }

            let name: String
            if nameLength > 0 {
                name = String(cString: nameBuffer)
            } else if !executablePath.isEmpty {
                name = (executablePath as NSString).lastPathComponent
            } else {
                continue
            }

            if isSearching {
                let haystack = (name + " " + executablePath).lowercased()
                guard haystack.contains(needle) else { continue }
            }

            candidates.append(
                TopProcess(
                    pid: pid,
                    name: name,
                    cpuPercent: cpuPercent,
                    memPercent: memPercent,
                    residentBytes: taskInfo.pti_resident_size,
                    executablePath: executablePath
                )
            )
        }

        swap(&previousCPUTimes, &currentCPUTimes)
        previousTimestamp = now

        switch sort {
        case .cpu:
            candidates.sort { lhs, rhs in
                lhs.cpuPercent == rhs.cpuPercent ? lhs.memPercent > rhs.memPercent : lhs.cpuPercent > rhs.cpuPercent
            }
        case .memory:
            candidates.sort { lhs, rhs in
                lhs.residentBytes == rhs.residentBytes ? lhs.memPercent > rhs.memPercent : lhs.residentBytes > rhs.residentBytes
            }
        }

        return Array(candidates.prefix(count))
    }

    /// Sends SIGTERM (`force == false`) or SIGKILL (`force == true`).
    /// Refuses pid <= 1 and the current process.
    func kill(pid: Int32, force: Bool = false) -> Bool {
        guard pid > 1, pid != getpid() else { return false }
        return Darwin.kill(pid, force ? SIGKILL : SIGTERM) == 0
    }
}
