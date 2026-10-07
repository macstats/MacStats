import SwiftUI

/// A flat, hairline-bordered surface. Panels sit on the popover's vibrancy
/// instead of floating on drop shadows, so the UI reads as one instrument
/// face rather than a stack of cards.
struct Panel<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = DS.Layout.panelPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .fill(DS.Palette.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.l, style: .continuous)
                    .strokeBorder(DS.Palette.hairline, lineWidth: 1)
            )
    }
}

/// Panel title row: small monochrome symbol tile, title, optional accessory.
struct PanelHeader<Accessory: View>: View {
    private let title: String
    private let symbol: String
    private let tint: Color
    private let accessory: Accessory

    init(
        _ title: String,
        symbol: String,
        tint: Color = DS.Palette.secondary,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: DS.Layout.headerIcon, height: DS.Layout.headerIcon)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                        .fill(tint.opacity(0.12))
                )

            Text(title)
                .font(DS.Text.title)
                .foregroundColor(DS.Palette.primary)

            Spacer(minLength: DS.Space.s)

            accessory
        }
    }
}

extension PanelHeader where Accessory == EmptyView {
    init(_ title: String, symbol: String, tint: Color = DS.Palette.secondary) {
        self.init(title, symbol: symbol, tint: tint) { EmptyView() }
    }
}

/// Compact capsule used for thermal state, charging state, and health.
struct StatusChip: View {
    let text: String
    var symbol: String?
    var level: StatusLevel = .normal
    var neutral: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(text)
                .font(DS.Text.micro)
        }
        .foregroundColor(neutral ? DS.Palette.secondary : level.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule(style: .continuous)
                .fill((neutral ? DS.Palette.secondary : level.color).opacity(0.14))
        )
        .accessibilityElement(children: .combine)
    }
}

/// One aligned label/value row. Values are monospaced so columns line up.
struct StatRowView: View {
    let label: String
    let value: String
    var icon: String?
    var iconColor: Color = DS.Palette.secondary
    var valueColor: Color = DS.Palette.primary

    var body: some View {
        HStack(spacing: DS.Space.s) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 12)
            }
            Text(label)
                .font(DS.Text.body)
                .foregroundColor(DS.Palette.secondary)
            Spacer(minLength: DS.Space.s)
            Text(value)
                .font(DS.Text.mono(11, weight: .medium))
                .foregroundColor(valueColor)
                .monospacedDigit()
        }
        .frame(height: DS.Layout.rowHeight)
        .accessibilityElement(children: .combine)
    }
}

/// Small color key used by legends and legends-like rows.
struct LegendDot: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(DS.Text.micro)
                    .foregroundColor(DS.Palette.secondary)
            }
            Text(value)
                .font(DS.Text.mono(11, weight: .medium))
                .foregroundColor(DS.Palette.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Row hover highlight, used by the process list.
struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DS.Space.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(hovering ? DS.Palette.hover : Color.clear)
            )
            .onHover { hovering = $0 }
            .animation(reduceMotion ? DS.Motion.none : DS.Motion.hover, value: hovering)
    }
}
