import SwiftUI

/// Blocky "L" mark reconstructed as vector shapes so it renders crisp at any
/// size and automatically retints in monochrome contexts (e.g. as a small
/// accent next to headings).
///
/// Composition mirrors the brand asset:
///  • solid black L silhouette
///  • pink swatch at the top of the vertical stem
///  • checkerboard-style white panel with four black dots below the pink
///  • two cyan stripes tucked into the horizontal foot
struct LookturaLogo: View {
    var size: CGFloat = 40
    /// When true, the colored inserts collapse to subtle ink tints. Use for
    /// dense UI (tab icons, list rows) where the brand palette would fight
    /// the surrounding chrome.
    var monochrome: Bool = false
    /// Applies a subtle floating shadow. Defaults to on.
    var showsShadow: Bool = true

    @Environment(\.appTheme) private var theme

    private var ink: Color { theme.ink }
    private var pink: Color {
        monochrome ? theme.ink.opacity(0.78) : Color(red: 0.93, green: 0.55, blue: 0.93)
    }
    private var cyan: Color {
        monochrome ? theme.ink.opacity(0.55) : Color(red: 0.60, green: 0.95, blue: 0.96)
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let stemW = s * 0.40
            let footH = s * 0.34
            let padX = s * 0.07

            ZStack(alignment: .topLeading) {
                // Black L silhouette (stem + foot).
                Rectangle()
                    .fill(ink)
                    .frame(width: stemW, height: s)

                Rectangle()
                    .fill(ink)
                    .frame(width: s, height: footH)
                    .offset(y: s - footH)

                // Pink block near the top of the stem.
                Rectangle()
                    .fill(pink)
                    .frame(width: stemW - padX * 2, height: s * 0.22)
                    .offset(x: padX, y: s * 0.085)

                // Polka-dot panel below the pink.
                ZStack {
                    Rectangle().fill(Color.white)
                    DotsGrid(color: ink)
                        .padding(s * 0.028)
                }
                .frame(width: stemW - padX * 2, height: s * 0.20)
                .offset(x: padX, y: s * 0.34)

                // Cyan stripes in the right end of the foot.
                VStack(spacing: s * 0.035) {
                    Rectangle().fill(cyan).frame(height: s * 0.055)
                    Rectangle().fill(cyan).frame(height: s * 0.055)
                }
                .frame(width: s * 0.46)
                .offset(x: s * 0.46, y: s * 0.76)
            }
            .frame(width: s, height: s, alignment: .topLeading)
            .shadow(color: showsShadow ? Color.black.opacity(0.18) : .clear, radius: 4, x: 0, y: 2)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Looktura")
    }
}

private struct DotsGrid: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let dot = min(w, h) * 0.24
            let insetX = (w - dot * 2) / 3
            let insetY = (h - dot * 2) / 3
            ZStack {
                Circle().fill(color).frame(width: dot, height: dot)
                    .position(x: insetX + dot / 2, y: insetY + dot / 2)
                Circle().fill(color).frame(width: dot, height: dot)
                    .position(x: insetX * 2 + dot * 1.5, y: insetY + dot / 2)
                Circle().fill(color).frame(width: dot, height: dot)
                    .position(x: insetX + dot / 2, y: insetY * 2 + dot * 1.5)
                Circle().fill(color).frame(width: dot, height: dot)
                    .position(x: insetX * 2 + dot * 1.5, y: insetY * 2 + dot * 1.5)
            }
        }
    }
}

/// Combined lockup: the `L` mark next to the LOOKTURA wordmark. Handy for
/// headers/onboarding where you want both brand elements together.
struct LookturaLockup: View {
    var logoSize: CGFloat = 28
    var wordmarkSize: CGFloat = 14
    var monochrome: Bool = false
    var spacing: CGFloat = 10

    var body: some View {
        HStack(spacing: spacing) {
            LookturaLogo(size: logoSize, monochrome: monochrome, showsShadow: false)
            Wordmark(size: wordmarkSize, tracking: 4)
        }
    }
}
