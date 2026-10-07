import SwiftUI

/// GPU utilization / memory card.
///
/// CONTRACT (frozen by root):
///   - `GPUDetailView(stats: GPUStats, history: [Double])` (history is utilization %).
///   - Only inserted by `PopoverContentView` when `stats.isAvailable`; keep the
///     current visual language: `SectionCardView` + `RingView`/`UsageBarView`/
///     `SparklineView` + `.font(.system(size: …))`.
struct GPUDetailView: View {
    let stats: GPUStats
    var history: [Double] = []

    var body: some View {
        EmptyView()
    }
}
