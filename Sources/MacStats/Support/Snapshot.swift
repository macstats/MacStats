import AppKit
import SwiftUI

/// Renders the popover content off-screen to a PNG.
///
/// Used to review layout/spacing without clicking through the UI, and to keep
/// the screenshots in `assets/` in sync with the real view tree:
/// `MacStats --snapshot assets/screenshot.png [dark]`
enum Snapshot {

    static func render(to path: String, dark: Bool, width: CGFloat = DS.Layout.popoverWidth, height: CGFloat = 600) {
        let settings = AppSettings()
        let viewModel = StatsViewModel(settings: settings)
        viewModel.isPopoverVisible = true
        viewModel.start()

        // Collect a couple of real samples before drawing.
        RunLoop.main.run(until: Date().addingTimeInterval(3))

        let root = PopoverContentView(viewModel: viewModel, settings: settings)
            .frame(width: width, height: height)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        hosting.layoutSubtreeIfNeeded()

        guard let representation = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            FileHandle.standardError.write(Data("snapshot: could not allocate bitmap\n".utf8))
            return
        }

        // The popover background is a real NSVisualEffectView, which renders
        // nothing off-screen — paint the window color first so the translucent
        // panels are judged against what the user actually sees.
        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: representation) {
            NSGraphicsContext.current = context
            NSColor.windowBackgroundColor.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        hosting.cacheDisplay(in: hosting.bounds, to: representation)

        guard let data = representation.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("snapshot: could not encode PNG\n".utf8))
            return
        }

        do {
            try data.write(to: URL(fileURLWithPath: path))
            print("snapshot written: \(path)")
        } catch {
            FileHandle.standardError.write(Data("snapshot: \(error)\n".utf8))
        }
    }
}
