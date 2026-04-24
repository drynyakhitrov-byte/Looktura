import SwiftUI

/// iOS 26 Liquid Glass material with graceful fallback to `.ultraThinMaterial` on iOS 17–25.
///
/// Use in place of a solid background when a surface should read as a floating glass element
/// (tab bars, sticky CTAs, toasts, icon buttons). Glass automatically tints based on the content
/// behind it, so avoid stacking additional opaque fills on top.
extension View {
    /// Plain regular glass inside the given shape.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Tinted regular glass — the tint is baked into the glass material on iOS 26+.
    @ViewBuilder
    func liquidGlass<S: Shape>(tint: Color, in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint), in: shape)
        } else {
            self.background(tint.opacity(0.55), in: shape)
                .background(.ultraThinMaterial, in: shape)
        }
    }

    /// Interactive glass that subtly responds to press state. Good for buttons.
    @ViewBuilder
    func liquidGlassInteractive<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
