import Foundation

/// Micro-benchmark for the sampling layer, run with `MacStats --benchmark`.
///
/// Reports three numbers:
/// - `refresh`      — the scheduled path (slow monitors back off when idle)
/// - `refresh full` — every monitor forced on every pass, i.e. the worst case
/// - `processes`    — one top-N process ranking
enum Benchmark {

    static func run() {
        let arguments = CommandLine.arguments
        let iterations: Int
        if let flagIndex = arguments.firstIndex(of: "--benchmark"),
           flagIndex + 1 < arguments.count,
           let parsed = Int(arguments[flagIndex + 1]) {
            iterations = max(parsed, 1)
        } else {
            iterations = 200
        }

        let monitor = SystemMonitor()
        _ = monitor.refresh()
        _ = monitor.topProcesses()
        for _ in 0..<5 {
            _ = monitor.refresh()
            _ = monitor.topProcesses()
        }

        var refresh: [Double] = []
        refresh.reserveCapacity(iterations)
        for _ in 0..<iterations {
            refresh.append(measure { _ = monitor.refresh() })
        }

        var fullRefresh: [Double] = []
        fullRefresh.reserveCapacity(iterations / 4)
        for _ in 0..<max(iterations / 4, 10) {
            fullRefresh.append(
                measure {
                    monitor.invalidateSlowCaches()
                    _ = monitor.refresh(mode: .interactive)
                }
            )
        }

        let processIterations = max(iterations / 10, 5)
        var processes: [Double] = []
        processes.reserveCapacity(processIterations)
        for _ in 0..<processIterations {
            processes.append(measure { _ = monitor.topProcesses() })
        }

        print("MacStats sampling benchmark (n = \(iterations))")
        print(report("refresh", refresh))
        print(report("refresh full", fullRefresh))
        print(report("processes", processes))
        print("")
        print("Per-monitor cost:")
        for component in monitor.componentBenchmarks(iterations: max(iterations / 4, 20)) {
            print(
                String(
                    format: "  %-10@ avg %7.4f ms   p95 %7.4f ms",
                    component.name as NSString,
                    component.average,
                    component.p95
                )
            )
        }
    }

    /// Runs `body` and returns elapsed milliseconds.
    private static func measure(_ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / 1_000_000
    }

    private static func report(_ name: String, _ samples: [Double]) -> String {
        let sorted = samples.sorted()
        let average = sorted.reduce(0, +) / Double(sorted.count)
        let median = sorted[sorted.count / 2]
        let p95 = sorted[Int(Double(sorted.count) * 0.95)]
        let worst = sorted.last ?? 0
        return String(
            format: "%-13@ avg %6.3f ms   p50 %6.3f ms   p95 %6.3f ms   max %6.3f ms",
            name as NSString,
            average,
            median,
            p95,
            worst
        )
    }
}
