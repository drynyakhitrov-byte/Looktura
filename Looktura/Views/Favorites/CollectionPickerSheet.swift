import SwiftUI

struct CollectionPickerSheet: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let productIds: [String]
    let onCreateNew: () -> Void
    let onClose: () -> Void

    @Environment(\.appTheme) private var theme

    private var products: [Product] {
        productIds.compactMap { repository.product(id: $0) }
    }

    private var isBulk: Bool { productIds.count > 1 }

    var body: some View {
        VStack(spacing: 0) {
            grabber
                .padding(.top, 8)

            header
                .padding(.horizontal, 22)
                .padding(.top, 14)

            productStrip
                .padding(.horizontal, 22)
                .padding(.top, 14)

            createRow
                .padding(.horizontal, 22)
                .padding(.top, 18)

            Divider()
                .background(theme.line)
                .padding(.horizontal, 22)
                .padding(.top, 14)

            if appState.collections.isEmpty {
                emptyState
                    .padding(.top, 28)
                    .padding(.horizontal, 22)
                Spacer()
            } else {
                list
                    .padding(.top, 8)
            }

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Keep the sheet's own background transparent so the liquid-glass
        // rows read against the blurred content behind the modal. The
        // presentationBackground in RootView uses .thinMaterial for a glass
        // substrate — solid theme.bg would defeat that. A very soft tint
        // keeps the ivory/black palette legible without covering the blur.
        .background(theme.bg.opacity(0.35).ignoresSafeArea())
    }

    private var grabber: some View {
        Capsule()
            .fill(theme.line)
            .frame(width: 40, height: 4)
            .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isBulk ? "ДОБАВИТЬ \(productIds.count)" : "ДОБАВИТЬ")
                .font(.mono(10))
                .tracking(1.8)
                .foregroundStyle(theme.muted)
            Text("В коллекцию")
                .font(.serif(26, weight: .regular))
                .tracking(-0.6)
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var productStrip: some View {
        if isBulk {
            bulkStrip
        } else if let p = products.first {
            singleStrip(p)
        }
    }

    private func singleStrip(_ p: Product) -> some View {
        HStack(spacing: 12) {
            ProductImage(product: p, cornerRadius: 10, showImageId: false)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.brand.uppercased())
                    .font(.mono(9))
                    .tracking(1.4)
                    .foregroundStyle(theme.muted)
                Text(p.title)
                    .font(.sans(13, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
            }
            Spacer()
            Text(p.price.formattedRubles)
                .font(.mono(12, weight: .semibold))
                .foregroundStyle(theme.ink)
        }
        .padding(12)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }

    private var bulkStrip: some View {
        HStack(spacing: -12) {
            ForEach(Array(products.prefix(5).enumerated()), id: \.element.id) { _, p in
                ProductImage(product: p, cornerRadius: 10, showImageId: false)
                    .frame(width: 48, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(theme.surface, lineWidth: 2)
                    )
            }
            if products.count > 5 {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.ink)
                    Text("+\(products.count - 5)")
                        .font(.mono(11, weight: .semibold))
                        .foregroundStyle(theme.accentInk)
                }
                .frame(width: 48, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme.surface, lineWidth: 2)
                )
            }
            Spacer()
            Text("\(products.count) вещей")
                .font(.mono(12, weight: .semibold))
                .foregroundStyle(theme.ink)
        }
        .padding(12)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }

    private var createRow: some View {
        Button(action: onCreateNew) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.accent.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.accentDeep)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Новая коллекция")
                        .font(.sans(15, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("Значок, цвет, вещи")
                        .font(.sans(12))
                        .foregroundStyle(theme.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // See CollectionPickerRow for the tap-hit explanation; same
            // story here. Making the whole row an explicit contentShape
            // guarantees the Button sees every pixel, not just the text.
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableRowStyle())
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.muted)
                .frame(width: 64, height: 64)
                .background(Circle().fill(theme.accent.opacity(0.12)))
            Text("Коллекций ещё нет")
                .font(.sans(14, weight: .medium))
                .foregroundStyle(theme.ink)
            Text("Создай первую — разложишь вещи по настроению.")
                .font(.sans(12))
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(appState.collections) { c in
                    CollectionPickerRow(
                        collection: c,
                        membershipState: membershipState(for: c),
                        thumbs: thumbs(for: c),
                        action: { toggleMembership(c.id) }
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 100)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Text("Готово")
                    .font(.sans(15, weight: .semibold))
                    .foregroundStyle(theme.accentInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(theme.ink))
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.6)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .padding(.top, 10)
        // Keep the footer transparent so the sheet's presentationBackground
        // (.thinMaterial) reads cleanly edge-to-edge. A solid theme.bg strip
        // here would be the "strange dark band" complaint.
        .background(Color.clear)
    }

    private func membershipState(for c: FavCollection) -> MembershipState {
        let present = productIds.filter { c.productIds.contains($0) }
        if present.count == productIds.count { return .all }
        if present.isEmpty { return .none }
        return .some
    }

    /// Bulk semantics:
    ///   `.all` → remove all selected products from the collection
    ///   `.some` / `.none` → add all selected products to the collection
    private func toggleMembership(_ collectionId: String) {
        let state = membershipState(for: appState.collection(id: collectionId) ?? FavCollection(name: ""))
        for pid in productIds {
            if state == .all {
                appState.removeFromCollection(productId: pid, collectionId: collectionId)
            } else {
                appState.addToCollection(productId: pid, collectionId: collectionId)
            }
        }
    }

    private func thumbs(for c: FavCollection) -> [Product] {
        c.productIds.prefix(3).compactMap { repository.product(id: $0) }
    }
}

enum MembershipState { case all, some, none }

private struct CollectionPickerRow: View {
    let collection: FavCollection
    let membershipState: MembershipState
    let thumbs: [Product]
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    private var isChecked: Bool { membershipState == .all }
    private var isPartial: Bool { membershipState == .some }

    /// Tint used for the row's mood puck, stroke, and check — honours the
    /// custom accent the user picked in the rich creator; falls back to the
    /// theme accent for legacy collections.
    private var rowAccent: Color {
        if let hex = collection.customAccentHex, !hex.isEmpty {
            return Color(hex: hex)
        }
        return theme.accent
    }

    var body: some View {
        // Why this shape:
        //   On iOS 26 the `liquidGlassInteractive` variant uses
        //   `glassEffect(.regular.interactive(), in:)` which installs its own
        //   press-feedback gesture recognizer. Nested inside a SwiftUI `Button`,
        //   that recognizer sometimes wins the touch on a real device even
        //   though the simulator (which synthesises touches through a different
        //   path) lets the Button handle them — producing the exact
        //   "works in sim, dead on phone" symptom the user reported.
        //
        //   Switching to plain `liquidGlass(in:)` drops the greedy interactive
        //   layer, and adding `.contentShape(RoundedRectangle(...))` makes the
        //   Button's hit region explicit so UIKit's button recognizer always
        //   sees the whole row as tappable. The glass press feedback now comes
        //   from the outer Button's own press animation via
        //   `PressableRowStyle` below — same spring feel as the capsule chips
        //   in FavoritesView, so presses look consistent across the app.
        Button(action: action) {
            HStack(spacing: 14) {
                moodIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(.sans(15, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("\(collection.productIds.count) " + countSuffix(collection.productIds.count))
                        .font(.mono(11))
                        .foregroundStyle(theme.muted)
                }
                Spacer(minLength: 8)
                thumbStack
                check
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isChecked || isPartial ? rowAccent : Color.white.opacity(0.22),
                        lineWidth: isChecked || isPartial ? 1.5 : 0.6
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableRowStyle())
    }

    private var moodIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(rowAccent.opacity(0.18))
                .frame(width: 40, height: 40)
            if let emoji = collection.customEmoji, !emoji.isEmpty {
                // Rich-creator collections render the chosen glyph as serif
                // text so "✦", "◌", "❋" keep their designed proportions. SF
                // Symbols can't render these code points correctly.
                Text(emoji)
                    .font(.serif(18, weight: .regular))
                    .foregroundStyle(rowAccent)
            } else {
                Image(systemName: collection.mood.glyph)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.accentDeep)
            }
        }
    }

    @ViewBuilder
    private var thumbStack: some View {
        if !thumbs.isEmpty {
            HStack(spacing: -10) {
                ForEach(Array(thumbs.enumerated()), id: \.element.id) { _, p in
                    ProductImage(product: p, cornerRadius: 8, showImageId: false)
                        .frame(width: 30, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(theme.surface, lineWidth: 2)
                        )
                }
            }
        }
    }

    private var check: some View {
        ZStack {
            Circle()
                .stroke(isChecked || isPartial ? rowAccent : theme.line, lineWidth: 1.5)
                .frame(width: 24, height: 24)
            if isChecked {
                Circle().fill(rowAccent).frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else if isPartial {
                // Partial fill: some products are in the collection, some aren't.
                Circle().fill(rowAccent.opacity(0.4)).frame(width: 24, height: 24)
                Rectangle()
                    .fill(.white)
                    .frame(width: 10, height: 2)
            }
        }
        // Cross-faded when the state flips so the tap feels acknowledged
        // immediately — without animation the stroke-to-fill swap pops hard.
        .animation(.easeOut(duration: 0.16), value: isChecked)
        .animation(.easeOut(duration: 0.16), value: isPartial)
    }

    private func countSuffix(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "вещь" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "вещи" }
        return "вещей"
    }
}

/// Press-responsive style for the whole collection row. Gives the row a
/// subtle spring press-scale without leaning on iOS 26's
/// `glassEffect(.regular.interactive())`, which on physical devices
/// occasionally swallowed the Button's tap (the root cause of the
/// "collection picker doesn't work on phone" bug).
private struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
