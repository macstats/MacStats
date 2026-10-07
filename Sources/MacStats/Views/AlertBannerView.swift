import SwiftUI

/// Warns about active threshold breaches at the top of the popover.
///
/// CONTRACT (frozen by root):
///   - `AlertBannerView(alerts: [ActiveAlert])`; renders nothing meaningful for an
///     empty array (root only inserts it when non-empty, keep the guard anyway).
struct AlertBannerView: View {
    let alerts: [ActiveAlert]

    var body: some View {
        EmptyView()
    }
}
