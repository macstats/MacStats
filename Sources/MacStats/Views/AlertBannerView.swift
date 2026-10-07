import SwiftUI

/// Warns about active threshold breaches at the top of the popover.
struct AlertBannerView: View, Equatable {
    let alerts: [ActiveAlert]

    private var tint: Color {
        alerts.contains { $0.severity == .critical } ? DS.Palette.alert : DS.Palette.warn
    }

    var body: some View {
        if alerts.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                ForEach(alerts) { alert in
                    HStack(alignment: .top, spacing: DS.Space.s) {
                        Image(systemName: alert.severity == .critical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(tint)
                            .frame(width: DS.Layout.headerIcon, height: DS.Layout.headerIcon)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                                    .fill(tint.opacity(0.14))
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(alert.title)
                                .font(DS.Text.title)
                                .foregroundColor(DS.Palette.primary)
                            Text(alert.message)
                                .font(DS.Text.body)
                                .foregroundColor(DS.Palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(alert.title). \(alert.message)")
                }
            }
            .padding(DS.Layout.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(tint.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            )
        }
    }
}
