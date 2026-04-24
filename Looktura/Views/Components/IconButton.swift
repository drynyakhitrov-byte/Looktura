import SwiftUI

/// Circular icon button. By default renders with Liquid Glass on iOS 26+ (with
/// `.ultraThinMaterial` fallback on iOS 17-25) so it floats over any background
/// without baking a solid surface tint into the UI.
struct IconButton<Content: View>: View {
    var size: CGFloat = 40
    var filled: Bool = false
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            content()
                .font(.system(size: size * 0.40, weight: .medium))
                .frame(width: size, height: size)
                .foregroundStyle(filled ? theme.accentInk : theme.ink)
                .background {
                    if filled {
                        Circle().fill(theme.ink)
                    }
                }
                .modifier(IconButtonGlass(filled: filled))
                .overlay(
                    Circle()
                        .strokeBorder(filled ? Color.clear : Color.white.opacity(0.28), lineWidth: 0.5)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct IconButtonGlass: ViewModifier {
    let filled: Bool

    func body(content: Content) -> some View {
        if filled {
            content
        } else {
            // Glass + gyro specular on top. The specular is a subtle white
            // sheen that drifts across the surface as the user tilts the
            // device — matches the motion-driven lensing Apple uses on its
            // own Liquid Glass surfaces.
            content
                .liquidGlass(in: Circle())
                .gyroSpecular(in: Circle(), intensity: 0.75)
        }
    }
}

extension IconButton where Content == Image {
    init(icon: String, size: CGFloat = 40, filled: Bool = false, action: @escaping () -> Void) {
        self.size = size
        self.filled = filled
        self.action = action
        self.content = { Image(systemName: icon) }
    }
}

/// Legacy alias kept for call sites that explicitly want glass styling. Now
/// identical to `IconButton` since the base already applies glass by default.
struct GlassIconButton: View {
    let icon: String
    var size: CGFloat = 40
    var filled: Bool = false
    var action: () -> Void

    var body: some View {
        IconButton(icon: icon, size: size, filled: filled, action: action)
    }
}
