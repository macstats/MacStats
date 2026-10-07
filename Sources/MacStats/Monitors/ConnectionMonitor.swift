import Foundation
import Darwin

/// Collects TCP connection state counts and listening ports.
///
/// Spawning `/usr/sbin/netstat` does not work from an ad-hoc signed app on
/// current macOS — the kernel attributes the child to the (untrusted) parent
/// and returns an empty PCB listing — so this enumerates sockets in-process via
/// libproc (`PROC_PIDLISTFDS` + `PROC_PIDFDSOCKETINFO`) instead. That covers the
/// current user's processes (root daemons are not visible) and needs no
/// privileges, no subprocess and therefore no timeout.
final class ConnectionMonitor {
    // BSD TCP states (netinet/tcp_fsm.h).
    private let stateListen: Int32 = 1
    private let stateEstablished: Int32 = 4
    private let stateCloseWait: Int32 = 5
    private let stateTimeWait: Int32 = 10

    private let socketInfoTCP: UInt32 = 2   // SOCKINFO_TCP

    func read() -> ConnectionStats {
        var stats = ConnectionStats()
        var ports = Set<Int>()
        var inspectedProcesses = 0

        for pid in processIdentifiers() {
            guard let fds = fileDescriptors(for: pid) else { continue }
            inspectedProcesses += 1

            for fd in fds where fd.proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
                var info = socket_fdinfo()
                let size = MemoryLayout<socket_fdinfo>.stride
                guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &info, Int32(size)) == size else {
                    continue
                }
                guard info.psi.soi_kind == socketInfoTCP else { continue }

                let state = info.psi.soi_proto.pri_tcp.tcpsi_state
                switch state {
                case stateListen:
                    stats.listening += 1
                    if let port = listeningPort(of: info), port > 0 {
                        ports.insert(port)
                    }
                case stateEstablished:
                    stats.established += 1
                case stateTimeWait:
                    stats.timeWait += 1
                case stateCloseWait:
                    stats.closeWait += 1
                default:
                    // State 0 is an unconnected socket, not a real connection.
                    if state != 0 { stats.other += 1 }
                }
            }
        }

        guard inspectedProcesses > 0 else { return ConnectionStats() }
        stats.isAvailable = true
        stats.listeningPorts = Array(ports.sorted().prefix(20))
        return stats
    }

    // MARK: - libproc helpers

    private func processIdentifiers() -> [pid_t] {
        var bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(bufferSize) / MemoryLayout<pid_t>.stride)
        bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferSize)
        let count = Int(bufferSize) / MemoryLayout<pid_t>.stride
        return pids.prefix(count).filter { $0 > 0 }
    }

    private func fileDescriptors(for pid: pid_t) -> [proc_fdinfo]? {
        let bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bufferSize > 0 else { return nil }

        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bufferSize) / MemoryLayout<proc_fdinfo>.stride)
        let read = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, bufferSize)
        guard read > 0 else { return nil }
        return Array(fds.prefix(Int(read) / MemoryLayout<proc_fdinfo>.stride))
    }

    /// `insi_lport` is stored in network byte order.
    private func listeningPort(of info: socket_fdinfo) -> Int? {
        let raw = info.psi.soi_proto.pri_tcp.tcpsi_ini.insi_lport
        let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: UInt32(bitPattern: raw)))
        return Int(port)
    }
}
