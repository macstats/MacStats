import SwiftUI

/// Warns about active threshold breaches at the top of the popover.
struct AlertBannerView: View {
    let alerts: [ActiveAlert]

    private var visible: [ActiveAlert] { Array(alerts.prefix(3)) }

    var body: some View {
        if alerts.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(visible) { alert in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: alert.severity == .critical
                              ? "exclamationmark.triangle.fill"
                              : "exclamationmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(alert.severity == .critical ? .red : .orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(alert.title)
                                .font(.system(size: 11, weight: .semibold))
                            Text(alert.message)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }

                if alerts.count > visible.count {
                    Text("…and \(alerts.count - visible.count) more")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.red.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red.opacity(0.25), lineWidth: 0.5)
            )
        }
    }
}
