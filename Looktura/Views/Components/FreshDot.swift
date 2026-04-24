import SwiftUI

struct FreshDot: View {
    let hours: Int
    @Environment(\.appTheme) private var theme

    private var color: Color {
        switch FreshnessLevel.from(hours: hours) {
        case .fresh: return theme.success
        case .recent: return Color(hex: "#D4A53A")
        case .stale: return theme.danger
        }
    }

    private var label: String {
        switch FreshnessLevel.from(hours: hours) {
        case .fresh: return "Свежее · \(hours)ч"
        case .recent: return "\(hours)ч назад"
        case .stale: return "Устарело"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
                .overlay(Circle().stroke(color.opacity(0.2), lineWidth: 3).scaleEffect(2.0))
            Text(label)
                .font(.mono(9, weight: .regular))
                .tracking(1.2)
                .foregroundStyle(theme.muted)
                .textCase(.uppercase)
        }
    }
}

struct FreshBadge: View {
    let hours: Int
    var style: Style = .onLight

    enum Style { case onLight, onDark, onSurface }

    private var color: Color {
        switch FreshnessLevel.from(hours: hours) {
        case .fresh: return Color(hex: "#4F8F6C")
        case .recent: return Color(hex: "#D4A53A")
        case .stale: return Color(hex: "#E9553C")
        }
    }

    private var label: String {
        switch FreshnessLevel.from(hours: hours) {
        case .fresh: return "Свежее"
        case .recent: return "\(hours)ч"
        case .stale: return "Старое"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.mono(9, weight: .regular))
                .tracking(1.2)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(background)
        .foregroundStyle(foreground)
        .clipShape(Capsule())
    }

    private var background: Color {
        switch style {
        case .onLight: return Color.white.opacity(0.85)
        case .onDark: return Color.white.opacity(0.12)
        case .onSurface: return Color.black.opacity(0.6)
        }
    }

    private var foreground: Color {
        switch style {
        case .onLight: return Color(hex: "#111010")
        case .onDark, .onSurface: return .white
        }
    }
}
