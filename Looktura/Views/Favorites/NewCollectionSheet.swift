import SwiftUI
import UIKit

/// Rich collection creator — name, icon glyph, and accent color.
///
/// Ported from the Claude Design "marketing-final" handoff
/// (`Screen_NewCollection`, screens-4.jsx lines 185–293). The prototype's
/// three-part composition (live preview → name + suggestions → icon grid +
/// color grid) becomes three vertically stacked sections. The preview box at
/// the top updates live as the user types / picks, so there's instant
/// feedback without a separate "preview" step.
///
/// Legacy behavior preserved: the created `FavCollection` still has a
/// `mood: CollectionMood` (defaulting to `.custom` for freshly-made
/// collections). Rendering callers that read `mood.glyph` keep working on old
/// data; anyone that knows about the new fields reads `customEmoji` and
/// `customAccentHex` for richer display.
struct NewCollectionSheet: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let seedProductIds: [String]
    let onCreated: (FavCollection) -> Void
    let onClose: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var name: String = ""
    @State private var emoji: String = "✦"
    @State private var accentHex: String = "#528A68"
    @FocusState private var nameFocused: Bool

    // MARK: Palette & glyphs

    /// Serif-friendly emoji/glyph palette from the design (screens-4.jsx
    /// line 191). These are all Unicode glyphs that render consistently in
    /// the app's serif face.
    private let emojis: [String] = ["✦", "◐", "◌", "❋", "△", "○", "☾", "♡", "✿"]

    /// Accent palette — direct port of screens-4.jsx line 192. Ordered so
    /// the first color (green / success) doubles as the default on open.
    private let accents: [String] = [
        "#528A68", "#B8A99A", "#3A4550", "#E9553C",
        "#D4A373", "#6B4F4F", "#827191", "#4B6C7B"
    ]

    /// Quick name suggestions (screens-4.jsx line 194). Tapping one populates
    /// the name field — faster than typing for the most common cases.
    private let suggestions: [String] = [
        "На работу", "Свидание", "Отпуск", "Каждый день", "На концерт", "Осенний базовый"
    ]

    private var seedProducts: [Product] {
        seedProductIds.compactMap { repository.product(id: $0) }
    }

    private var accent: Color { Color(hex: accentHex) }

    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Без названия" : trimmed
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber.padding(.top, 8)

            header
                .padding(.horizontal, 22)
                .padding(.top, 14)

            ScrollView {
                VStack(spacing: 22) {
                    livePreview
                        .padding(.top, 18)

                    nameSection

                    iconSection

                    colorSection

                    if !seedProducts.isEmpty {
                        seedHint
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 140)
            }

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.bg.opacity(0.35).ignoresSafeArea())
        .onAppear {
            if name.isEmpty {
                name = ""
            }
            // Small delay before raising the keyboard — the sheet's own
            // presentation animation is ~0.3s on iOS; raising the keyboard
            // inside that window makes the layout jitter. Waiting until the
            // sheet's at rest lets the keyboard slide up cleanly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                nameFocused = true
            }
        }
    }

    // MARK: - Pieces

    private var grabber: some View {
        Capsule()
            .fill(theme.line)
            .frame(width: 40, height: 4)
            .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("НОВАЯ КАПСУЛА")
                .font(.mono(10))
                .tracking(1.8)
                .foregroundStyle(theme.muted)
            Text("Собери свою коллекцию")
                .font(.serif(26, weight: .regular))
                .tracking(-0.6)
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Gradient tile that updates live with the picked accent + glyph +
    /// name. Frosted glass puck holds the chosen symbol exactly like the
    /// design (linear gradient `160deg, accent → accent*0.55`).
    private var livePreview: some View {
        VStack(spacing: 10) {
            glyphPuck
                .padding(.top, 22)
            Text(displayName)
                .font(.serif(24, weight: .regular))
                .tracking(-0.3)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.55)],
                        startPoint: UnitPoint(x: 0.1, y: 0.0),
                        endPoint: UnitPoint(x: 0.9, y: 1.0)
                    )
                )
                .shadow(color: accent.opacity(0.32), radius: 22, x: 0, y: 14)
        )
        // Spring on every picker change so color / emoji / name updates
        // feel like they flow into the preview rather than cutting to it.
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: accentHex)
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: emoji)
        .animation(.easeOut(duration: 0.18), value: displayName)
    }

    private var glyphPuck: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.25))
                .frame(width: 72, height: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 0.6)
                )
                .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(emoji)
                .font(.serif(36, weight: .regular))
                .foregroundStyle(.white)
                // Subtle pop on change so glyph picks feel tactile.
                .transition(.scale.combined(with: .opacity))
                .id(emoji)
        }
    }

    // MARK: Name + suggestions

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("НАЗВАНИЕ")

            HStack(spacing: 8) {
                TextField(
                    "",
                    text: $name,
                    prompt: Text("Например, На работу").foregroundColor(theme.muted)
                )
                .font(.sans(16, weight: .medium))
                .foregroundStyle(theme.ink)
                .focused($nameFocused)
                .submitLabel(.done)
                .textInputAutocapitalization(.sentences)

                if !name.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.14)) { name = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(theme.muted)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        nameFocused ? theme.ink.opacity(0.6) : Color.white.opacity(0.22),
                        lineWidth: nameFocused ? 1.2 : 0.6
                    )
            )
            .animation(.easeOut(duration: 0.18), value: nameFocused)

            // Suggestion chips — flow-wrap so they wrap gracefully on
            // narrower devices.
            FlowLayout(spacing: 6) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        withAnimation(.easeOut(duration: 0.14)) { name = s }
                    } label: {
                        Text(s)
                            .font(.sans(11.5, weight: .medium))
                            .foregroundStyle(name == s ? theme.accentInk : theme.muted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(name == s ? theme.ink : theme.pill)
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableMicroStyle())
                }
            }
        }
    }

    // MARK: Icon grid

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ЗНАЧОК")
            // 9 options fit 5 per row on an iPhone 13 width (22+22 padding,
            // 48pt tile + 8pt gap → 5 wide). FlowLayout keeps this robust if
            // the list ever changes length.
            FlowLayout(spacing: 8) {
                ForEach(emojis, id: \.self) { g in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            emoji = g
                        }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(emoji == g ? theme.ink : Color.clear)
                                .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            emoji == g ? theme.ink : Color.white.opacity(0.22),
                                            lineWidth: emoji == g ? 1 : 0.6
                                        )
                                )
                            Text(g)
                                .font(.serif(22, weight: .regular))
                                .foregroundStyle(emoji == g ? theme.accentInk : theme.ink)
                        }
                        .frame(width: 48, height: 48)
                        .scaleEffect(emoji == g ? 1.05 : 1.0)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressableMicroStyle())
                }
            }
        }
    }

    // MARK: Color grid

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("ЦВЕТ")
            FlowLayout(spacing: 10) {
                ForEach(accents, id: \.self) { hex in
                    let color = Color(hex: hex)
                    let isActive = accentHex == hex
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            accentHex = hex
                        }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        isActive ? theme.ink : Color.clear,
                                        lineWidth: 3
                                    )
                            )
                            .scaleEffect(isActive ? 1.08 : 1.0)
                            .shadow(
                                color: isActive ? color.opacity(0.45) : .clear,
                                radius: isActive ? 10 : 0,
                                x: 0,
                                y: isActive ? 6 : 0
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(PressableMicroStyle())
                    .accessibilityLabel(Text("Цвет \(hex)"))
                }
            }
        }
    }

    // MARK: Seed hint + bottom bar

    private var seedHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent)
            Text(seedHintText)
                .font(.sans(12))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accent.opacity(0.1))
        )
    }

    private var seedHintText: String {
        if seedProducts.count == 1, let first = seedProducts.first {
            return "«\(first.title)» — первая вещь в капсуле"
        }
        let n = seedProducts.count
        let word: String
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { word = "вещь" }
        else if (2...4).contains(mod10) && !(12...14).contains(mod100) { word = "вещи" }
        else { word = "вещей" }
        return "Добавим \(n) \(word) в новую капсулу"
    }

    private var bottomBar: some View {
        let canCreate = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 10) {
            Button(action: onClose) {
                Text("Отмена")
                    .font(.sans(15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .overlay(Capsule().stroke(theme.line, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableMicroStyle())

            Button(action: create) {
                HStack(spacing: 8) {
                    Text("Создать капсулу")
                        .font(.sans(15, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(theme.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(theme.ink))
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(PressableMicroStyle())
            .disabled(!canCreate)
            .opacity(canCreate ? 1.0 : 0.4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background(Color.clear)
        .animation(.easeOut(duration: 0.18), value: canCreate)
    }

    // MARK: Section label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.mono(9))
            .tracking(1.6)
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private func create() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
        let c = appState.createCollection(
            name: name,
            mood: .custom,
            customEmoji: emoji,
            customAccentHex: accentHex,
            seedProductIds: seedProductIds
        )
        onCreated(c)
    }
}

/// Reusable micro press-feedback. Keeps the whole sheet's interactive feel
/// consistent — every tappable tile / chip / button does the same 0.94
/// spring-scale on press.
private struct PressableMicroStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
