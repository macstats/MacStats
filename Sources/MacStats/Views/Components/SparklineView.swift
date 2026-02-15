import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let maxValue: Double
    var color: Color = .blue

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let count = data.count

            if count > 1 {
                // Fill
                Path { path in
                    let stepX = w / CGFloat(count - 1)
                    path.move(to: CGPoint(x: 0, y: h))
                    for (i, val) in data.enumerated() {
                        let y = h - (CGFloat(val / maxValue) * h)
                        path.addLine(to: CGPoint(x: stepX * CGFloat(i), y: y))
                    }
                    path.addLine(to: CGPoint(x: stepX * CGFloat(count - 1), y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    let stepX = w / CGFloat(count - 1)
                    for (i, val) in data.enumerated() {
                        let y = h - (CGFloat(val / maxValue) * h)
                        let pt = CGPoint(x: stepX * CGFloat(i), y: y)
                        if i == 0 {
                            path.move(to: pt)
                        } else {
                            path.addLine(to: pt)
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
