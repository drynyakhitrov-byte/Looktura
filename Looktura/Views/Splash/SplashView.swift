import SwiftUI

/// First view shown on cold launch. Runs a brief brand reveal (logo spin-in,
/// ambient rings, wordmark fade) and then hands off to whichever flow the app
/// state dictates (onboarding or main tab).
///
/// Design source: Claude Design "marketing-final" handoff bundle — Screen_Splash
/// in `screens-1.jsx`, ported to native SwiftUI. The prototype uses a generic
/// 6-petal flower mark; we use the real Looktura `L` logo instead.
///
/// Total runtime: ~1.5s. Deliberately short — a splash that overstays its
/// welcome feels like an ad. If `RootView` decides the onboarding is done and
/// the main app is ready, the view simply fades out when `onComplete` is
/// invoked by the internal timer.
struct SplashView: View {
    let onComplete: () -> Void

    @Environment(\.appTheme) private var theme

    /// Animation stages — each `@State` drives a single property so SwiftUI's
    /// implicit animations can interpolate them independently with different
    /// timing curves.
    @State private var logoIn: Bool = false
    @State private var textIn: Bool = false
    @State private var ringsIn: Bool = false
    @State private var pulsing: Bool = false

    /// How long the splash stays on screen before `onComplete()` fires.
    private let displayDuration: Duration = .milliseconds(1500)

    var body: some View {
        ZStack {
            theme.bg
                .ignoresSafeArea()

            // --- Ambient concentric rings -------------------------------------
            // Two soft concentric circles that scale in on first appear and
            // then breathe gently. Pure decoration — they anchor the mark in
            // the composition and add a sense of depth the way the JSX mockup
            // does.
            Circle()
                .stroke(theme.line, lineWidth: 1)
                .frame(width: 320, height: 320)
                .scaleEffect(ringsIn ? (pulsing ? 1.03 : 1.0) : 0.6)
                .opacity(ringsIn ? (pulsing ? 0.9 : 0.6) : 0)

            Circle()
                .stroke(theme.accent.opacity(0.25), lineWidth: 1)
                .frame(width: 200, height: 200)
                .scaleEffect(ringsIn ? (pulsing ? 1.05 : 1.0) : 0.6)
                .opacity(ringsIn ? (pulsing ? 1.0 : 0.7) : 0)

            // --- Logo + wordmark stack ---------------------------------------
            VStack(spacing: 18) {
                LookturaLogo(size: 84, showsShadow: false)
                    .rotationEffect(.degrees(logoIn ? 0 : -140))
                    .scaleEffect(logoIn ? 1.0 : 0.3)
                    .opacity(logoIn ? 1 : 0)

                Text("Looktura")
                    .font(.serif(34, weight: .regular))
                    .tracking(-0.6)
                    .foregroundStyle(theme.ink)
                    .opacity(textIn ? 1 : 0)
                    .offset(y: textIn ? 0 : 6)
            }

            // --- Bottom tagline ----------------------------------------------
            VStack {
                Spacer()
                Text("MOSCOW · FRESH FINDS")
                    .font(.mono(10, weight: .medium))
                    .tracking(2.2)
                    .foregroundStyle(theme.muted)
                    .padding(.bottom, 90)
                    .opacity(textIn ? 1 : 0)
            }
        }
        .onAppear {
            // Rings scale up first (a breath faster than the logo), so the
            // logo feels like it snaps into the middle of an already-breathing
            // composition rather than the whole thing appearing at once.
            withAnimation(.easeOut(duration: 0.55)) {
                ringsIn = true
            }
            // Springy logo reveal — mirrors the JSX `lk-logo-spin` keyframe
            // (rotate(-180deg) scale(.3) opacity:0 → 0/1/1).
            withAnimation(.spring(response: 0.7, dampingFraction: 0.62)) {
                logoIn = true
            }
            // Wordmark + tagline fade in after the logo has landed, same
            // cadence as the JSX `lk-wordmark-fade` delay.
            withAnimation(.easeOut(duration: 0.55).delay(0.45)) {
                textIn = true
            }
            // Slow breath, starts once rings are visible.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
        }
        .task {
            // Hold on screen for the full display duration, then hand off.
            // `Task.sleep` is cancellation-aware, so if SwiftUI decides to
            // tear the view down (unlikely for a splash, but safe) the
            // onComplete callback is skipped cleanly.
            try? await Task.sleep(for: displayDuration)
            onComplete()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Looktura")
    }
}
