import SwiftUI

// MARK: - Linear progress

private struct BarShape: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = fraction.unitClamped
        let width = rect.width * CGFloat(clamped)
        guard width > 0.5 else { return Path() }
        let radius = min(rect.height / 2, width / 2)
        return Path(
            roundedRect: CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height),
            cornerRadius: radius
        )
    }
}

/// A single-value progress bar. No `GeometryReader`: the shape reads its own rect.
struct ProgressBar: View {
    let fraction: Double
    var height: CGFloat = 6
    var color: Color = DS.Palette.accent
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(DS.Palette.track)
            BarShape(fraction: fraction)
                .fill(color)
                .animation(animated && !reduceMotion ? DS.Motion.bar : DS.Motion.none, value: fraction)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Segmented progress (memory composition, disk usage breakdown)

/// Segments rendered as hard-stop gradient stops inside one capsule:
/// proportional, gap-free, and free of per-segment layout passes.
struct SegmentedBar: View {
    struct Segment: Equatable {
        let value: Double
        let color: Color
        let label: String
    }

    let segments: [Segment]
    let total: Double
    var height: CGFloat = 6

    private var stops: [Gradient.Stop] {
        guard total > 0 else { return [Gradient.Stop(color: DS.Palette.track, location: 0)] }
        var result: [Gradient.Stop] = []
        var cursor: Double = 0
        for segment in segments {
            let fraction = (segment.value / total).unitClamped
            guard fraction > 0.002 else { continue }
            let start = cursor
            cursor = min(cursor + fraction, 1)
            result.append(Gradient.Stop(color: segment.color, location: start))
            result.append(Gradient.Stop(color: segment.color, location: cursor))
        }
        if result.isEmpty { return [Gradient.Stop(color: DS.Palette.track, location: 0)] }
        return result
    }

    var body: some View {
        Capsule(style: .continuous)
            .fill(LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing))
            .frame(height: height)
            .background(Capsule(style: .continuous).fill(DS.Palette.track))
            .accessibilityHidden(true)
    }
}

// MARK: - Trace (sparkline)

/// The app's signature readout: a precise line trace with a hairline grid
/// and a highlighted "now" dot, drawn imperatively in a single `Canvas`.
struct TraceView: View {
    let values: [Double]
    var maxValue: Double
    var color: Color
    var showsFill: Bool = true
    var showsEndDot: Bool = true
    var gridLines: Int = 2

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let upper = max(maxValue, 0.0001)

            // Hairline reference grid.
            if gridLines > 0 {
                var grid = Path()
                for index in 1...gridLines {
                    let y = size.height * CGFloat(index) / CGFloat(gridLines + 1)
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(DS.Palette.grid), lineWidth: 0.5)
            }

            let stepX = size.width / CGFloat(values.count - 1)
            func point(_ index: Int) -> CGPoint {
                let value = values[index]
                let normalized = (value / upper).unitClamped
                return CGPoint(x: stepX * CGFloat(index), y: size.height * (1 - CGFloat(normalized)))
            }

            if showsFill {
                var fill = Path()
                fill.move(to: CGPoint(x: 0, y: size.height))
                for index in values.indices { fill.addLine(to: point(index)) }
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.closeSubpath()
                context.fill(
                    fill,
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.28), color.opacity(0.02)]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }

            var line = Path()
            for index in values.indices {
                let pt = point(index)
                if index == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
            }
            context.stroke(
                line,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )

            if showsEndDot, let last = values.last {
                let normalized = (last / upper).unitClamped
                let center = CGPoint(x: size.width - 2, y: size.height * (1 - CGFloat(normalized)))
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
                    with: .color(color.opacity(0.25))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)),
                    with: .color(color)
                )
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Ring gauge

private struct RingShape: Shape {
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius = (min(rect.width, rect.height) / 2) - 1
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(
            center: center,
            radius: max(radius, 1),
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * fraction.unitClamped),
            clockwise: false
        )
        return path
    }
}

struct RingGauge<Content: View>: View {
    let fraction: Double
    var lineWidth: CGFloat = 5
    var color: Color = DS.Palette.accent
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        fraction: Double,
        lineWidth: CGFloat = 5,
        color: Color = DS.Palette.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.fraction = fraction
        self.lineWidth = lineWidth
        self.color = color
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(DS.Palette.track, lineWidth: lineWidth)
                .padding(lineWidth / 2)
            RingShape(fraction: fraction)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .padding(lineWidth / 2)
                .animation(reduceMotion ? DS.Motion.none : DS.Motion.ring, value: fraction)
            content
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Small indicators

/// Per-core usage column used by the CPU panel.
struct CoreBar: View {
    let usage: Double
    var height: CGFloat = 18

    private var color: Color {
        switch StatusLevel.usage(usage / 100) {
        case .normal: return DS.Palette.cpu
        case .elevated: return DS.Palette.warn
        case .critical: return DS.Palette.alert
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(DS.Palette.track)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(height: height * CGFloat((usage / 100).unitClamped))
        }
        .frame(height: height)
    }
}

/// Four ascending bars for WiFi signal strength.
struct SignalBars: View {
    let bars: Int
    var level: StatusLevel

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .fill(index < bars ? level.color : DS.Palette.track)
                    .frame(width: 3, height: 5 + CGFloat(index) * 2.5)
            }
        }
        .frame(height: 13, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
