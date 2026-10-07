import AppKit

// Headless diagnostics mode: collect one real sample, print it, exit.
// Used by CI and by feature development to verify monitors without a GUI.
if CommandLine.arguments.contains("--dump-once") {
    DumpOnce.run()
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
