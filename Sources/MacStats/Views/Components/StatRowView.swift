import SwiftUI

struct StatRowView: View {
    let label: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(iconColor)
                    .frame(width: 14)
            }
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
        }
        .frame(height: 18)
    }
}
