import SwiftUI
import UIKit

/// Single-screen mood warm-up. Shown right after the Intro sequence and
/// before Auth — ported from the Claude Design "marketing-final" handoff
/// (`Screen_Onboarding` in screens-1.jsx, lines 54–127). The prototype's
/// "Что тебе к лицу сегодня?" 2-column grid of 6 styled tiles with a
/// multi-select CTA.
///
/// Persists into the existing `appState.quizPicks.styles` set so the later
/// QuizView and any downstream recommendation logic stay in sync — this
/// screen is additive, not a replacement for the quiz.
struct MoodPickerView: View {
    @Bindable var appState: AppState
    let onNext: () -> Void
    let onSkip: () -> Void

    @Environment(\.appTheme) private var theme

    /// Six moods from the design (screens-1.jsx lines 55–62). We store the
    /// label as the selection key so it matches the existing quiz/style
    /// vocabulary used elsewhere in the app.
    private let moods: [Mood] = [
        Mood(key: "Minimal",   label: "Minimal",   glyph: "□"),
        Mood(key: "Vintage",   label: "Vintage",   glyph: "◇"),
        Mood(key: "Street",    label: "Street",    glyph: "△"),
        Mood(key: "Tailoring", label: "Tailoring", glyph: "○"),
        Mood(key: "Casual",    label: "Casual",    glyph: "◎"),
        Mood(key: "Romantic",  label: "Romantic",  glyph: "❋"),
    ]

    /// Triggers the staggered tile-in animation on first appear.
    @State private var revealed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 4)

            title
                .padding(.top, 34)

            moodGrid
                .padding(.top, 28)

            Spacer()

            ctaButton
                .padding(.top, 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.bg.ignoresSafeArea())
        .onAppear {
            // Slight delay so the previous step's exit transition fully
            // clears before the tiles spring in — avoids visual collision.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
                    revealed = true
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Text("ШАГ")
                    .font(.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(theme.muted)
                Text("01 · 01")
                    .font(.mono(10))
                    .tracking(1.4)
                    .foregroundStyle(theme.ink)
            }
            Spacer()
            Button(action: onSkip) {
                Text("пропустить")
                    .font(.sans(14))
                    .foregroundStyle(theme.muted)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableChipMicroStyle())
        }
    }

    // MARK: - Title

    private var title: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Serif display with an italic "к лицу" so the tone matches the
            // design's `<em>`-bracketed emphasis (screens-1.jsx line 78).
            (Text("Что тебе ")
                + Text("к лицу").italic()
                + Text(" сегодня?"))
            .font(.serif(38, weight: .regular))
            .tracking(-1.0)
            .lineSpacing(-4)
            .foregroundStyle(theme.ink)

            Text("Выбери 2–3 настроения. Можно изменить в любой момент.")
                .font(.sans(15))
                .lineSpacing(3)
                .foregroundStyle(theme.muted)
                .frame(maxWidth: 320, alignment: .leading)
        }
    }

    // MARK: - Grid

    private var moodGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(Array(moods.enumerated()), id: \.element.id) { idx, m in
                moodTile(mood: m, index: idx)
            }
        }
    }

    private func moodTile(mood m: Mood, index idx: Int) -> some View {
        let isActive = appState.quizPicks.styles.contains(m.key)

        return Button {
            toggle(m.key)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(m.glyph)
                    .font(.serif(32, weight: .regular))
                    .foregroundStyle(isActive ? theme.accentInk.opacity(0.9) : theme.ink.opacity(0.8))
                    // Little rotate + scale on toggle mirrors the design's
                    // `transform: active ? rotate(8deg) scale(1.1) : none`.
                    .rotationEffect(.degrees(isActive ? 8 : 0))
                    .scaleEffect(isActive ? 1.1 : 1.0)

                Spacer(minLength: 0)

                Text(m.label)
                    .font(.sans(15, weight: .medium))
                    .foregroundStyle(isActive ? theme.accentInk : theme.ink)
            }
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
            .frame(height: 110, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isActive ? theme.ink : theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isActive ? theme.ink : theme.line, lineWidth: 1)
            )
            .shadow(
                color: isActive ? theme.ink.opacity(0.28) : .clear,
                radius: isActive ? 14 : 0,
                x: 0,
                y: isActive ? 8 : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            // Staggered reveal — each tile enters 50ms after the previous,
            // straight from the design's `animation: lk-fade-up 400ms … i*50ms`.
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 14)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.88)
                    .delay(Double(idx) * 0.05),
                value: revealed
            )
        }
        .buttonStyle(PressableChipMicroStyle())
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: isActive)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        let count = appState.quizPicks.styles.count
        let enabled = count > 0

        return Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
            onNext()
        } label: {
            HStack(spacing: 10) {
                Text(enabled ? "Дальше · \(count)" : "Выбери хотя бы одно")
                    .font(.sans(15, weight: .semibold))
                    .contentTransition(.numericText())
                if enabled {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundStyle(theme.accentInk)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(theme.ink))
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
            )
            .shadow(color: theme.ink.opacity(enabled ? 0.35 : 0), radius: 20, x: 0, y: 10)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableChipMicroStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.4)
        .animation(.easeOut(duration: 0.2), value: enabled)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: count)
    }

    // MARK: - Logic

    private func toggle(_ key: String) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
        if appState.quizPicks.styles.contains(key) {
            appState.quizPicks.styles.remove(key)
        } else {
            appState.quizPicks.styles.insert(key)
        }
    }

    struct Mood: Identifiable, Hashable {
        let key: String
        let label: String
        let glyph: String
        var id: String { key }
    }
}

/// Local micro-press style shared by the header "skip", the tiles, and the
/// bottom CTA. Kept fileprivate to this view so tweaking its feel doesn't
/// ripple into unrelated buttons. If other onboarding screens want the same
/// behaviour, hoist it to a shared `ButtonStyle`.
private struct PressableChipMicroStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
