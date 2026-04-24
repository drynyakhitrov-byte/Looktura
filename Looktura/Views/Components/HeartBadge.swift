import SwiftUI

/// Unified "favorite" affordance used anywhere the app surfaces a saved-state
/// indicator or a tap-to-favorite button. The canonical style lives in the
/// Favorites grid — a red (`theme.danger`) heart on liquid-glass circle with
/// a hairline white stroke and a soft drop-shadow — and this view makes it
/// reusable so DetailView's top bar, DetailView's sticky CTA, the Favorites
/// card itself, and anything else all share one visual language.
///
/// Sizing is proportional: the heart glyph scales with the circle so a 40-pt
/// top-bar button and a 30-pt corner badge feel like members of the same
/// family rather than independent decisions.
///
/// Behaviour:
///   • `isFilled: true`  → solid red heart (saved)
///   • `isFilled: false` → outline heart in the theme ink color (tap to save)
///   • `action: nil`     → renders as a pure badge (caller owns its tap target)
///   • `action: non-nil` → wraps itself in a plain-styled Button
struct HeartBadge: View {
    var size: CGFloat = 30
    var isFilled: Bool = true
    var action: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        Image(systemName: isFilled ? "heart.fill" : "heart")
            .font(.system(size: size * (14.0 / 30.0), weight: .semibold))
            .foregroundStyle(isFilled ? theme.danger : theme.ink)
            .frame(width: size, height: size)
            .liquidGlass(in: Circle())
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            .contentShape(Circle())
    }
}
