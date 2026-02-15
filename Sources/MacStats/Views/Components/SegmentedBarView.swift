import SwiftUI

struct SegmentedBarView: View {
    let segments: [(value: Double, color: Color, label: String)]
    let total: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                    let fraction = total > 0 ? seg.value / total : 0
                    if fraction > 0.005 {
                        RoundedRectangle(cornerRadius: height / 2)
                            .fill(seg.color)
                            .frame(width: max(geo.size.width * fraction - 1, 2))
                    }
                }
                Spacer(minLength: 0)
            }
            .background(
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(.quaternary)
            )
        }
        .frame(height: height)
    }
}
