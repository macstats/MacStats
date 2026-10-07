import Foundation

/// Collects TCP connection state counts and listening ports.
///
/// Uses `/usr/sbin/netstat -an -p tcp` (a system binary, no third-party
/// dependency) with a hard timeout, and is called at most once every ~30s.
final class ConnectionMonitor {
    private let executablePath = "/usr/sbin/netstat"
    private let timeout: TimeInterval = 2.0

    func read() -> ConnectionStats {
        guard let output = runNetstat(), let stats = parse(output) else {
            return ConnectionStats()
        }
        return stats
    }

    // MARK: - Snapshot

    private func runNetstat() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["-an", "-p", "tcp"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }

        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Parsing

    private func parse(_ output: String) -> ConnectionStats? {
        var stats = ConnectionStats()
        var sawTCP = false
        var ports = Set<Int>()

        for line in output.split(separator: "\n") {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count >= 5, fields[0].hasPrefix("tcp") else { continue }
            sawTCP = true

            let state = fields.count > 5 ? fields[5].uppercased() : ""
            switch state {
            case "ESTABLISHED": stats.established += 1
            case "LISTEN": stats.listening += 1
            case "TIME_WAIT": stats.timeWait += 1
            case "CLOSE_WAIT": stats.closeWait += 1
            default: stats.other += 1
            }

            if state == "LISTEN", let port = port(fromLocal: fields[3]), port > 0 {
                ports.insert(port)
            }
        }

        guard sawTCP else { return nil }
        stats.isAvailable = true
        stats.listeningPorts = Array(ports.sorted().prefix(20))
        return stats
    }

    private func port(fromLocal raw: String) -> Int? {
        guard let dot = raw.lastIndex(of: ".") else { return nil }
        return Int(raw[raw.index(after: dot)...])
    }
}
