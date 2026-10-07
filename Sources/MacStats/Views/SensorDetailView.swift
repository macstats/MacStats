import SwiftUI

/// Thermal / fan card fed by `SensorMonitor` (SMC).
///
/// CONTRACT (frozen by root):
///   - `SensorDetailView(stats: SensorStats)`.
///   - Only inserted by `PopoverContentView` when `stats.isAvailable`.
///   - Hide rows whose data is missing (nil temperature, empty fan list) instead of
///     rendering placeholders.
struct SensorDetailView: View {
    let stats: SensorStats

    var body: some View {
        EmptyView()
    }
}
