import SwiftUI

struct RingView: View {
    let progress: Double
    var lineWidth: CGFloat = 6
    var colors: [Color] = [.blue, .cyan]
    var trackOpacity: Double = 0.12

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(colors.first?.opacity(trackOpacity) ?? Color.gray.opacity(trackOpacity), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        colors: colors + [colors.first ?? .blue],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}
