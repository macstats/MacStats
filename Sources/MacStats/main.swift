import AppKit

// Headless diagnostics mode: collect one real sample, print it, exit.
// Used by CI and by feature development to verify monitors without a GUI.
if CommandLine.arguments.contains("--dump-once") {
    DumpOnce.run()
    exit(0)
}

if CommandLine.arguments.contains("--kill-test") {
    DumpOnce.runKillTest()
    exit(0)
}

if CommandLine.arguments.contains("--alert-test") {
    DumpOnce.runAlertTest()
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
