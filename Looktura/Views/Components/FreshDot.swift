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

    @Environment(\.appTheme) private var theme

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
        // Theme-adaptive pill (for `.onLight` callers like SwipeCard's
        // top-right badge) uses ultraThinMaterial + a theme-tinted surface
        // so the pill reads as glass in BOTH themes:
        //   • ivory: white-ish surface + near-black ink
        //   • noir:  near-black surface + near-white ink
        // Previously the `.onLight` style hard-coded `Color.white.opacity(0.85)`
        // + `#111010` text — fine on light product photos, but in the dark
        // theme the whole card canvas reads dark while the pill stayed
        // bright white, which the user correctly called out as visually
        // inconsistent with the now-adaptive top-LEFT store pill on the
        // same card (see `SwipeCard.storeTag`). Fix mirrors that pill:
        // theme.surface@0.88 behind ultraThinMaterial, theme.ink text,
        // theme.line hairline stroke.
        .background(
            Group {
                switch style {
                case .onLight:
                    ZStack {
                        Capsule().fill(theme.surface.opacity(0.88))
                        Capsule().fill(.ultraThinMaterial)
                    }
                case .onDark:
                    Capsule().fill(Color.white.opacity(0.12))
                case .onSurface:
                    Capsule().fill(Color.black.opacity(0.6))
                }
            }
        )
        .overlay(
            Group {
                if style == .onLight {
                    Capsule().strokeBorder(theme.line, lineWidth: 0.5)
                }
            }
        )
        .foregroundStyle(foreground)
        .clipShape(Capsule())
    }

    private var foreground: Color {
        switch style {
        case .onLight: return theme.ink
        case .onDark, .onSurface: return .white
        }
    }
}
