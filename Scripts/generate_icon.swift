#!/usr/bin/env swift

import AppKit
import CoreGraphics

// === macOS Icon Design: no text, bold shapes, readable at 16px ===

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size

    // === 1. Background: rounded rect, dark gradient ===
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cr = s * 0.22
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cr, cornerHeight: cr, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let bg1 = NSColor(red: 0.09, green: 0.10, blue: 0.17, alpha: 1).cgColor
    let bg2 = NSColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 1).cgColor
    let bgGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [bg1, bg2] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bgGrad, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: 0), options: [])
    ctx.restoreGState()

    // Subtle border
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.07).cgColor)
    ctx.setLineWidth(max(s * 0.008, 0.5))
    ctx.strokePath()
    ctx.restoreGState()

    // === 2. Large gauge ring (occupies ~60% of icon) ===
    let center = CGPoint(x: s * 0.5, y: s * 0.55)
    let ringRadius = s * 0.30
    let ringWidth = s * 0.065

    // Track (full arc, 240 degrees)
    let trackStart: CGFloat = .pi * 0.833   // 150 deg
    let trackEnd: CGFloat = .pi * 0.167     // 30 deg (clockwise = bottom gap)

    ctx.saveGState()
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.07).cgColor)
    ctx.setLineWidth(ringWidth)
    ctx.setLineCap(.round)
    ctx.addArc(center: center, radius: ringRadius, startAngle: trackStart, endAngle: trackEnd, clockwise: true)
    ctx.strokePath()
    ctx.restoreGState()

    // Colored arc (~75% of the track = 180 degrees)
    let fillEnd: CGFloat = .pi * 0.30
    drawGradientArc(ctx: ctx, center: center, radius: ringRadius, lineWidth: ringWidth,
                    startAngle: trackStart, endAngle: fillEnd, clockwise: true,
                    colors: [
                        NSColor(red: 0.0, green: 0.90, blue: 0.90, alpha: 1),   // cyan
                        NSColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1),   // blue
                        NSColor(red: 0.58, green: 0.30, blue: 1.0, alpha: 1),   // purple
                    ])

    // Glow dot at the tip of the arc
    let dotAngle = fillEnd
    let dotX = center.x + ringRadius * cos(dotAngle)
    let dotY = center.y + ringRadius * sin(dotAngle)
    let dotR = ringWidth * 0.7
    ctx.saveGState()
    let glowColor = NSColor(red: 0.58, green: 0.30, blue: 1.0, alpha: 0.5).cgColor
    ctx.setShadow(offset: .zero, blur: s * 0.03, color: glowColor)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: dotX - dotR/2, y: dotY - dotR/2, width: dotR, height: dotR))
    ctx.restoreGState()

    // === 3. Bar chart inside the ring ===
    let barCount = 5
    let totalBarWidth = s * 0.34
    let barGap = s * 0.025
    let barW = (totalBarWidth - barGap * CGFloat(barCount - 1)) / CGFloat(barCount)
    let barBaseY = center.y - s * 0.17
    let maxBarH = s * 0.30
    let barStartX = center.x - totalBarWidth / 2

    let heights: [CGFloat] = [0.40, 0.70, 1.0, 0.55, 0.82]
    let barColorSets: [(NSColor, NSColor)] = [
        (NSColor(red: 0.0, green: 0.85, blue: 0.85, alpha: 0.5),
         NSColor(red: 0.0, green: 0.90, blue: 0.90, alpha: 1.0)),
        (NSColor(red: 0.10, green: 0.55, blue: 1.0, alpha: 0.5),
         NSColor(red: 0.15, green: 0.60, blue: 1.0, alpha: 1.0)),
        (NSColor(red: 0.35, green: 0.40, blue: 1.0, alpha: 0.5),
         NSColor(red: 0.40, green: 0.45, blue: 1.0, alpha: 1.0)),
        (NSColor(red: 0.50, green: 0.30, blue: 1.0, alpha: 0.5),
         NSColor(red: 0.55, green: 0.35, blue: 1.0, alpha: 1.0)),
        (NSColor(red: 0.20, green: 0.50, blue: 1.0, alpha: 0.5),
         NSColor(red: 0.25, green: 0.55, blue: 1.0, alpha: 1.0)),
    ]

    for i in 0..<barCount {
        let x = barStartX + CGFloat(i) * (barW + barGap)
        let h = maxBarH * heights[i]
        let rect = CGRect(x: x, y: barBaseY, width: barW, height: h)
        let rr = barW * 0.35
        let barPath = CGPath(roundedRect: rect, cornerWidth: rr, cornerHeight: rr, transform: nil)

        ctx.saveGState()
        ctx.addPath(barPath)
        ctx.clip()
        let (c1, c2) = barColorSets[i]
        let bGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [c1.cgColor, c2.cgColor] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(bGrad,
                               start: CGPoint(x: x, y: barBaseY),
                               end: CGPoint(x: x, y: barBaseY + h), options: [])
        ctx.restoreGState()
    }

    image.unlockFocus()
    return image
}

// MARK: - Gradient arc drawing

func drawGradientArc(ctx: CGContext, center: CGPoint, radius: CGFloat, lineWidth: CGFloat,
                     startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool,
                     colors: [NSColor]) {
    let segments = 50
    let totalAngle: CGFloat = clockwise
        ? (startAngle > endAngle ? startAngle - endAngle : startAngle + 2 * .pi - endAngle)
        : (endAngle > startAngle ? endAngle - startAngle : endAngle + 2 * .pi - startAngle)

    for i in 0..<segments {
        let t = CGFloat(i) / CGFloat(segments)
        let color = lerpColor(colors: colors, t: t)
        let a1 = clockwise ? startAngle - totalAngle * t : startAngle + totalAngle * t
        let a2 = clockwise ? startAngle - totalAngle * (t + 1.0 / CGFloat(segments))
                           : startAngle + totalAngle * (t + 1.0 / CGFloat(segments))

        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.addArc(center: center, radius: radius, startAngle: a1, endAngle: a2, clockwise: clockwise)
        ctx.strokePath()
        ctx.restoreGState()
    }
}

func lerpColor(colors: [NSColor], t: CGFloat) -> NSColor {
    guard colors.count > 1 else { return colors.first ?? .white }
    let seg = t * CGFloat(colors.count - 1)
    let i = min(Int(seg), colors.count - 2)
    let lt = seg - CGFloat(i)
    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
    var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
    colors[i].getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
    colors[i+1].getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    return NSColor(red: r1+(r2-r1)*lt, green: g1+(g2-g1)*lt, blue: b1+(b2-b1)*lt, alpha: a1+(a2-a1)*lt)
}

// === Generate iconset ===

let iconsetPath = ".build/MacStats.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, sz) in sizes {
    let img = drawIcon(size: sz)
    guard let tiff = img.tiffRepresentation,
          let bmp = NSBitmapImageRep(data: tiff),
          let png = bmp.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
    print("  \(name) (\(Int(sz))px)")
}
print("Done. iconutil -c icns \(iconsetPath) -o .build/MacStats.icns")
