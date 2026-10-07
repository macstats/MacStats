import AppKit

// Headless self-check: `MacStats --benchmark [iterations]` measures the cost
// of one sampling pass and exits. Used by Scripts/bench.sh.
if CommandLine.arguments.contains("--benchmark") {
    Benchmark.run()
    exit(0)
}

// Off-screen render of the popover: `MacStats --snapshot <path> [dark]`
if let flagIndex = CommandLine.arguments.firstIndex(of: "--snapshot") {
    let arguments = CommandLine.arguments
    let path = flagIndex + 1 < arguments.count ? arguments[flagIndex + 1] : "screenshot.png"
    let dark = arguments.contains("dark")
    Snapshot.render(to: path, dark: dark)
    exit(0)
}

// Headless diagnostics: `MacStats --dump-once` prints one real sample and
// exits, so monitors can be verified without a GUI session.
if CommandLine.arguments.contains("--dump-once") {
    DumpOnce.run()
    exit(0)
}

// Diagnostics that exercise the process kill path with a disposable child.
if CommandLine.arguments.contains("--kill-test") {
    DumpOnce.runKillTest()
    exit(0)
}

// Feeds synthetic threshold breaches through AlertCenter.
if CommandLine.arguments.contains("--alert-test") {
    DumpOnce.runAlertTest()
    exit(0)
}

let app = NSApplication.shared
// Deliberate product choice: MacStats lives in the menu bar only, with no
// Dock icon and no main window.
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
