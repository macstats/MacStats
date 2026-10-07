import AppKit

/// Draws the menu bar history chart into a reused bitmap context.
///
/// The previous implementation created a fresh `NSImage` with a drawing
/// closure, a fresh `CGContext`, and bridged `NSColor` → `CGColor` for every
/// bar on every tick. This renderer allocates once (and again only when the
/// display scale or appearance changes) and keeps all colors as `CGColor`.
final class MenuBarChartRenderer {
    private let size: NSSize
    private let scale: CGFloat
    private let context: CGContext
    private let appearance: NSAppearance.Name

    private let colorNormal: CGColor
    private let colorElevated: CGColor
    private let colorCritical: CGColor
    private let colorBaseline: CGColor

    private let barWidth: CGFloat = 2
    private let barGap: CGFloat = 1.5

    init?(size: NSSize, scale: CGFloat, appearance: NSAppearance.Name) {
        self.size = size
        self.scale = scale
        self.appearance = appearance

        let pixelWidth = Int((size.width * scale).rounded(.up))
        let pixelHeight = Int((size.height * scale).rounded(.up))
        guard pixelWidth > 0, pixelHeight > 0,
              let context = CGContext(
                data: nil,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        context.scaleBy(x: scale, y: scale)
        context.setShouldAntialias(true)
        self.context = context

        // Resolve dynamic colors once, for this appearance.
        var normal = NSColor.systemBlue.cgColor
        var elevated = NSColor.systemOrange.cgColor
        var critical = NSColor.systemRed.cgColor
        var baseline = NSColor.tertiaryLabelColor.cgColor
        NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance {
            normal = NSColor.systemBlue.cgColor
            elevated = NSColor.systemOrange.cgColor
            critical = NSColor.systemRed.cgColor
            baseline = NSColor.tertiaryLabelColor.cgColor
        }
        colorNormal = normal
        colorElevated = elevated
        colorCritical = critical
        colorBaseline = baseline
    }

    /// True when this renderer can still be used for the given environment.
    func matches(size: NSSize, scale: CGFloat, appearance: NSAppearance.Name) -> Bool {
        self.size == size && self.scale == scale && self.appearance == appearance
    }

    func image(samples: [Double]) -> NSImage {
        context.clear(CGRect(origin: .zero, size: size))

        // Baseline hairline keeps the chart anchored to the menu bar text.
        context.setAlpha(1)
        context.setFillColor(colorBaseline)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: 1 / scale))

        let maxBars = max(Int((size.width + barGap) / (barWidth + barGap)), 1)
        let values = samples.count > maxBars ? Array(samples.suffix(maxBars)) : samples
        guard !values.isEmpty else {
            return makeImage()
        }

        let usableHeight = size.height - 1
        let startX = size.width - CGFloat(values.count) * (barWidth + barGap) + barGap
        let denominator = Double(max(values.count - 1, 1))

        for (index, value) in values.enumerated() {
            let fraction = (value / 100).unitClamped
            let height = max(CGFloat(fraction) * usableHeight, 0.75)
            let age = Double(index) / denominator

            context.setAlpha(0.35 + 0.65 * age)
            context.setFillColor(color(for: value))
            context.fill(
                CGRect(
                    x: startX + CGFloat(index) * (barWidth + barGap),
                    y: 0,
                    width: barWidth,
                    height: height
                )
            )
        }

        return makeImage()
    }

    private func color(for value: Double) -> CGColor {
        if value >= 80 { return colorCritical }
        if value >= 50 { return colorElevated }
        return colorNormal
    }

    private func makeImage() -> NSImage {
        context.setAlpha(1)
        guard let cgImage = context.makeImage() else {
            return NSImage(size: size)
        }
        let image = NSImage(cgImage: cgImage, size: size)
        image.isTemplate = false
        return image
    }
}
