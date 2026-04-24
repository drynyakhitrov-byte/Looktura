import SwiftUI

struct Chip: View {
    let label: String
    var isActive: Bool = false
    var tight: Bool = false
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.sans(tight ? 12 : 13, weight: .medium))
                .tracking(0.2)
                .foregroundStyle(isActive ? (theme.isDark ? theme.accentInk : theme.bg) : theme.ink)
                .padding(.horizontal, tight ? 11 : 14)
                .frame(height: tight ? 28 : 34)
                .background {
                    if isActive {
                        Capsule().fill(theme.ink)
                    } else {
                        Capsule().fill(Color.clear).liquidGlass(in: Capsule())
                    }
                }
                .overlay(
                    Capsule().strokeBorder(
                        isActive ? theme.ink : Color.white.opacity(0.25),
                        lineWidth: isActive ? 1 : 0.5
                    )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
