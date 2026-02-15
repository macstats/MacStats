import SwiftUI

struct UsageBarView: View {
    let value: Double
    let maxValue: Double
    var color: Color = .blue
    var height: CGFloat = 6

    private var fraction: Double {
        guard maxValue > 0 else { return 0 }
        return min(max(value / maxValue, 0), 1)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(gradient)
                    .frame(width: max(geo.size.width * fraction, fraction > 0 ? height : 0))
            }
        }
        .frame(height: height)
        .animation(.easeInOut(duration: 0.6), value: fraction)
    }
}
