import SwiftUI
import UIKit

struct FavoritesView: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let onOpenProduct: (String) -> Void
    let onGoToFeed: () -> Void
    let onOpenCollection: (String) -> Void
    let onOpenRoute: (String?) -> Void
    let onCreateNewCollection: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var selectedCollectionId: String? = nil

    /// Selection state lives on `AppState` so the bottom bar in `RootView` can
    /// morph between the tab bar and the bulk action pill. See
    /// `AppState.bulkSelection`.
    private var isSelectionMode: Bool { appState.isInBulkSelection }
    private var selectedIds: Set<String> { appState.bulkSelection ?? [] }

    private var allFavorited: [Product] {
        repository.products.filter { appState.isFavorite($0.id) }
    }

    private var selectedCollection: FavCollection? {
        guard let id = selectedCollectionId else { return nil }
        return appState.collection(id: id)
    }

    private var visibleProducts: [Product] {
        if let c = selectedCollection {
            return c.productIds.compactMap { repository.product(id: $0) }
        }
        return allFavorited
    }

    private var uniqueStoreCount: Int {
        Set(visibleProducts.map(\.storeId)).count
    }

    private var heroTitle: String {
        selectedCollection?.name ?? "Все"
    }

    private var heroMood: CollectionMood {
        selectedCollection?.mood ?? .wish
    }

    var body: some View {
        // Outer `VStack` with the header + collections strip pinned ABOVE the
        // vertical ScrollView. See the long comment on `collectionChip` below
        // for why the strip must live outside the scroll — short version: on
        // physical iPhone hardware, the outer vertical scroll recognizer
        // would swallow both horizontal swipes and button taps inside the
        // nested horizontal ScrollView.
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 58)
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isSelectionMode)

            collectionsStrip
                .padding(.top, 16)
                .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if allFavorited.isEmpty {
                        EmptyFavoritesView(onBrowse: onGoToFeed)
                            .padding(.horizontal, 22)
                            .padding(.top, 40)
                            .padding(.bottom, 120)
                    } else {
                        heroCollection
                            .padding(.horizontal, 22)
                            .padding(.top, 10)
                            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isSelectionMode)

                        if visibleProducts.isEmpty {
                            emptyCollection
                                .padding(.horizontal, 22)
                                .padding(.top, 40)
                                .padding(.bottom, 120)
                        } else {
                            grid
                                .padding(.horizontal, 22)
                                .padding(.top, 20)
                                .padding(.bottom, 140)
                                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isSelectionMode)
                                .animation(.easeOut(duration: 0.18), value: selectedIds)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    LookturaLogo(size: 22, showsShadow: false)
                    Text("ИЗБРАННОЕ")
                        .font(.mono(10))
                        .tracking(1.6)
                        .foregroundStyle(theme.muted)
                }
                Text(isSelectionMode ? "\(selectedIds.count) выбрано" : "Твои сохранёнки")
                    .font(.serif(30, weight: .regular))
                    .tracking(-0.8)
                    .foregroundStyle(theme.ink)
                    .contentTransition(.numericText())
            }
            Spacer()
            if isSelectionMode {
                Button(action: exitSelectionMode) {
                    Text("Готово")
                        .font(.sans(13, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlass(in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onCreateNewCollection) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Коллекция")
                            .font(.sans(12, weight: .medium))
                    }
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .liquidGlass(in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Collections strip

    private var collectionsStrip: some View {
        // Note: we intentionally do NOT apply `.disabled(isSelectionMode)` or
        // a blanket `.opacity(...)` on the strip itself — `.disabled` alters
        // hit-testing at the container level, and combined with the
        // nested-scroll environment this proved brittle on real hardware.
        // Instead each chip (and the "Новая" button) dims its content inside
        // its label and guards its action with `guard !isSelectionMode`, so
        // the hit region stays the full capsule.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                collectionChip(
                    id: nil,
                    name: "Все",
                    count: allFavorited.count,
                    glyph: "heart.fill"
                )

                ForEach(appState.collections) { c in
                    collectionChip(
                        id: c.id,
                        name: c.name,
                        count: c.productIds.count,
                        glyph: c.mood.glyph
                    )
                }

                Button {
                    guard !isSelectionMode else { return }
                    onCreateNewCollection()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Новая")
                            .font(.sans(13, weight: .medium))
                    }
                    .foregroundStyle(theme.accentDeep)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .overlay(
                        Capsule().stroke(theme.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                    .contentShape(Capsule())
                    .opacity(isSelectionMode ? 0.5 : 1.0)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
        }
    }

    private func collectionChip(id: String?, name: String, count: Int, glyph: String) -> some View {
        let isActive = selectedCollectionId == id
        // Gesture strategy — why `Button { } label: { }.buttonStyle(.plain)`:
        //
        //   Three earlier attempts failed in different ways:
        //     1. Raw `Button` wrapping the whole chip — the previous version
        //        had `.contentShape(Capsule())` on the OUTER chip, so the
        //        Button's hit region shrank to the Text frame and the rest of
        //        the chip wasn't tappable.
        //     2. Plain `HStack` + `.onTapGesture` — a tap gesture inside a
        //        horizontal ScrollView requires zero finger translation, and
        //        human taps move a few pixels, so the pan recognizer won.
        //     3. Plain `HStack` + `.highPriorityGesture(TapGesture())` — same
        //        zero-translation constraint as (2), just at higher priority;
        //        still lost when the finger moved even slightly.
        //     4. Even the `Button { } label: { }.buttonStyle(.plain)` pattern
        //        — which works reliably for `Chip` in `Looktura/Views/Catalog/CatalogView.swift`
        //        — still failed for this strip on physical iPhone hardware
        //        (iOS 17+), while working fine in the simulator. Root cause:
        //        the strip used to live INSIDE the page's outer vertical
        //        `ScrollView`, and on real devices the outer vertical scroll
        //        recognizer would swallow both the horizontal swipe and the
        //        button tap inside the nested horizontal `ScrollView`. The
        //        simulator doesn't reproduce this because its pan recognizer
        //        is less aggressive, and `CatalogView` didn't trip on it
        //        because its scroll geometry is larger and the gesture chain
        //        resolves differently. The fix: lift the strip out of the
        //        outer vertical `ScrollView` — see `body` above, where the
        //        header + `collectionsStrip` are pinned above a separate
        //        inner `ScrollView`. With only one scroll axis crossing the
        //        strip's hit region, UIKit's button recognizer wins cleanly.
        //
        //   This version copies the pattern used by `Chip` in CatalogView,
        //   which reliably taps inside a horizontal ScrollView:
        //     • `Button { action } label: { content }` — lets UIKit's button
        //       gesture recognizer handle the tap with its own finger-wobble
        //       tolerance (same tolerance the system uses for tab bar items).
        //     • `.contentShape(Capsule())` lives INSIDE the label, on the
        //       styled view — so the whole capsule is hittable, not just the
        //       text frame.
        //     • `.buttonStyle(.plain)` strips the default blue tint so we
        //       keep our own glass styling; it does not affect hit-testing.
        //
        //   Behaviour:
        //     • "Все" (nil id)        → filter-only, stay on this screen
        //     • named collection chip → navigate to CollectionDetail
        return Button {
            // In selection mode the chip is visually dimmed but still
            // hit-testable — guard here so the tap is a no-op without
            // breaking the hit region (see the note on `collectionsStrip`).
            guard !isSelectionMode else { return }
            if let id {
                withAnimation(.easeOut(duration: 0.18)) {
                    selectedCollectionId = id
                }
                onOpenCollection(id)
            } else {
                withAnimation(.easeOut(duration: 0.18)) {
                    selectedCollectionId = nil
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: glyph)
                    .font(.system(size: 10, weight: .semibold))
                Text(name)
                    .font(.sans(13, weight: .medium))
                Text("\(count)")
                    .font(.mono(10))
                    .opacity(0.6)
            }
            .foregroundStyle(isActive ? theme.accentInk : theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background {
                if isActive {
                    Capsule().fill(theme.ink)
                } else {
                    Capsule().fill(Color.clear).liquidGlass(in: Capsule())
                }
            }
            .overlay(
                Capsule().strokeBorder(
                    isActive ? theme.ink : Color.white.opacity(0.25),
                    lineWidth: isActive ? 1 : 0.5
                )
            )
            .contentShape(Capsule())
            .opacity(isSelectionMode ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: Hero

    private var heroCollection: some View {
        // Replaced the 3-image-strip hero with a color-driven abstract cover.
        // Three butted-together product crops never compose well — the seams
        // looked like collage tears, and the text above them needed a heavy
        // scrim that washed the title into near-invisibility.
        //
        // The new cover is a blurred single cover image (from the first
        // product, if any) beneath a mesh gradient built from the palette of
        // products in the selection. Reading the title becomes easy because
        // the palette is chosen from the items themselves — it tints the
        // surface rather than covering it.
        ZStack(alignment: .bottomLeading) {
            heroBackdrop
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            // Subtle bottom-only scrim — just enough lift so the text block
            // reads crisp without blacking out the palette above it.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(0.08), location: 0.45),
                    .init(color: .black.opacity(0.28), location: 0.80),
                    .init(color: .black.opacity(0.50), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack {
                HStack {
                    Spacer()
                    heroActions
                }
                .padding(14)

                Spacer()

                Button {
                    if let id = selectedCollectionId {
                        onOpenCollection(id)
                    }
                } label: {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(visibleProducts.count) ВЕЩЕЙ · \(uniqueStoreCount) " + storeSuffix(uniqueStoreCount))
                                .font(.mono(10))
                                .tracking(1.8)
                                .foregroundStyle(.white)
                            HStack(spacing: 10) {
                                Image(systemName: heroMood.glyph)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(
                                        Circle()
                                            .fill(.white.opacity(0.18))
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.white.opacity(0.35), lineWidth: 0.6)
                                    )
                                Text(heroTitle)
                                    .font(.serif(30, weight: .regular))
                                    .tracking(-0.6)
                                    .foregroundStyle(.white)
                            }
                        }
                        Spacer()
                        if selectedCollectionId != nil {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.ink)
                                .frame(width: 36, height: 36)
                                .liquidGlass(in: Circle())
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
                        }
                    }
                    .padding(18)
                }
                .buttonStyle(.plain)
                .disabled(selectedCollectionId == nil || isSelectionMode)
            }
            .frame(height: 200)
        }
        .frame(height: 200)
        .opacity(isSelectionMode ? 0.55 : 1.0)
    }

    /// Abstract color-driven backdrop. Layers:
    ///   1. A blurred single cover photo (from the first visible product) —
    ///      provides tactile grain behind the palette so the surface reads
    ///      as a real material, not a flat swatch.
    ///   2. A mesh of large soft blobs using colors derived from each
    ///      product's `color` attribute — maps the palette of the
    ///      collection onto the cover.
    ///   3. A thin white overlay for sheen + base saturation.
    @ViewBuilder
    private var heroBackdrop: some View {
        ZStack {
            if let first = visibleProducts.first {
                ProductImage(product: first, cornerRadius: 0, showImageId: false)
                    .blur(radius: 40)
                    .saturation(1.15)
                    .opacity(0.85)
            } else {
                theme.pill
            }

            // Color palette blobs — one per dominant color, positioned at
            // fixed corners so the composition doesn't reflow when items
            // change. Gaussian-style soft edges via RadialGradient.
            ForEach(Array(paletteColors.prefix(4).enumerated()), id: \.offset) { idx, color in
                RadialGradient(
                    colors: [color.opacity(0.65), color.opacity(0)],
                    center: paletteCenter(idx),
                    startRadius: 10,
                    endRadius: 220
                )
                .blendMode(.plusLighter)
            }

            // Soft vignette to bind the palette to the corners and keep the
            // mid-plane where the title sits readable.
            RadialGradient(
                colors: [.clear, .black.opacity(0.14)],
                center: .center,
                startRadius: 60,
                endRadius: 240
            )
        }
    }

    /// Maps a product's `color` attribute to a Color via the curated Catalog
    /// palette. Falls back to neutrals when the color name isn't in the table.
    private var paletteColors: [Color] {
        let names = Set(visibleProducts.map { $0.color.lowercased() })
        let mapped: [Color] = Catalog.namedColors.compactMap { c in
            names.contains(c.name.lowercased()) ? Color(hex: c.hex) : nil
        }
        if mapped.isEmpty {
            return [
                Color(hex: "#B8A99A"),
                Color(hex: "#5C6F5C"),
                Color(hex: "#D4C4B0")
            ]
        }
        return mapped
    }

    private func paletteCenter(_ i: Int) -> UnitPoint {
        switch i {
        case 0: return UnitPoint(x: 0.18, y: 0.22)
        case 1: return UnitPoint(x: 0.82, y: 0.30)
        case 2: return UnitPoint(x: 0.72, y: 0.82)
        default: return UnitPoint(x: 0.25, y: 0.75)
        }
    }

    private var heroActions: some View {
        HStack(spacing: 8) {
            if uniqueStoreCount >= 2 && !visibleProducts.isEmpty {
                Button {
                    onOpenRoute(selectedCollectionId)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Маршрут")
                            .font(.sans(12, weight: .semibold))
                    }
                    .foregroundStyle(theme.accentInk)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Capsule().fill(theme.accent))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyCollection: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedCollection?.mood.glyph ?? "square.stack.3d.up")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(theme.muted)
                .frame(width: 72, height: 72)
                .background(Circle().fill(theme.accent.opacity(0.14)))
            Text("В коллекции пока пусто")
                .font(.serif(22, weight: .regular))
                .tracking(-0.4)
                .foregroundStyle(theme.ink)
            Text("Зажми вещь в Избранном и выбери эту коллекцию.")
                .font(.sans(13))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.muted)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 18) {
            ForEach(visibleProducts) { p in
                FavoriteCard(
                    product: p,
                    store: repository.store(id: p.storeId),
                    memberships: appState.collections(containing: p.id),
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedIds.contains(p.id),
                    onTap: {
                        if isSelectionMode {
                            toggleSelection(p.id)
                        } else {
                            onOpenProduct(p.id)
                        }
                    },
                    onLongPress: { enterSelection(with: p.id) },
                    onUnfavorite: {
                        // Tapping the small heart on a Favorites card removes
                        // the product from favorites (and from every
                        // collection — see `toggleFavorite`). Light haptic so
                        // the action feels physical, matching the "saved"
                        // haptic the swipe-right gesture fires elsewhere.
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.easeOut(duration: 0.2)) {
                            appState.toggleFavorite(p.id)
                        }
                    }
                )
            }
        }
    }

    // MARK: Selection logic

    private func enterSelection(with id: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
            appState.enterBulkSelection(with: id)
        }
    }

    /// Called when the user taps a card while already in selection mode.
    /// `allowAutoExit` is false when the tapped card is the one that just
    /// entered selection mode via long-press — otherwise the finger-lift would
    /// instantly remove the only selected item and kick the user out.
    private func toggleSelection(_ id: String, allowAutoExit: Bool = true) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.easeOut(duration: 0.16)) {
            appState.toggleBulkSelection(id, autoExitWhenEmpty: allowAutoExit)
        }
    }

    private func exitSelectionMode() {
        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
            appState.exitBulkSelection()
        }
    }

    // MARK: Helpers

    private func storeSuffix(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "МАГАЗИН" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "МАГАЗИНА" }
        return "МАГАЗИНОВ"
    }

    private func itemSuffix(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "вещь" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "вещи" }
        return "вещей"
    }
}

private struct FavoriteCard: View {
    let product: Product
    let store: Store?
    let memberships: [FavCollection]
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onUnfavorite: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var isPressed: Bool = false

    var body: some View {
        // Build the card as a plain view (no Button) so we have full control
        // over gesture resolution. The previous Button + simultaneousGesture
        // pair fired BOTH the long-press (enter selection) AND the tap
        // (toggle selection) on the same release, immediately kicking the
        // user out of a mode they'd just entered. `.onTapGesture` and
        // `.onLongPressGesture` are mutually exclusive — exactly one fires
        // per interaction.
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ProductImage(product: product, cornerRadius: 14, showImageId: false)
                    .aspectRatio(3.0/4.0, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isSelected ? theme.accent : Color.clear, lineWidth: 3)
                    )
                    .overlay(alignment: .topLeading) {
                        if isSelectionMode {
                            selectionBadge
                                .padding(8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                // Tappable heart — fires onUnfavorite. Passing `action:` to
                // HeartBadge wraps it in a plain Button, whose hit-test
                // consumes the tap before it bubbles up to the card's outer
                // `.onTapGesture` (which would otherwise open the product).
                // Hit-testing is disabled in selection mode so the hidden
                // badge can't catch invisible taps while the card is in
                // multi-select.
                HeartBadge(
                    size: 30,
                    isFilled: true,
                    action: isSelectionMode ? nil : onUnfavorite
                )
                .padding(10)
                .opacity(isSelectionMode ? 0.0 : 1.0)
                .allowsHitTesting(!isSelectionMode)
            }

            if let s = store {
                Text(s.name.uppercased())
                    .font(.mono(9))
                    .tracking(1.3)
                    .foregroundStyle(theme.muted)
            }

            Text(product.title)
                .font(.sans(13, weight: .medium))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Text(product.price.formattedRubles)
                    .font(.mono(11, weight: .semibold))
                    .foregroundStyle(theme.ink)
                if memberships.count > 0 {
                    Text("·").foregroundStyle(theme.muted)
                    Text("в \(memberships.count) кол.")
                        .font(.mono(10))
                        .foregroundStyle(theme.accentDeep)
                }
            }
        }
        .scaleEffect(isSelected ? 0.96 : (isPressed ? 0.985 : 1.0))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(
            minimumDuration: 0.35,
            maximumDistance: 30,
            perform: { onLongPress() },
            onPressingChanged: { pressing in
                withAnimation(.easeOut(duration: 0.12)) { isPressed = pressing }
            }
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isSelected)
        .animation(.easeOut(duration: 0.18), value: isSelectionMode)
    }

    private var selectionBadge: some View {
        ZStack {
            Circle()
                .fill(isSelected ? theme.accent : Color.white.opacity(0.82))
                .frame(width: 26, height: 26)
                .overlay(
                    Circle().strokeBorder(theme.ink.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
                )
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.accentInk)
            }
        }
    }
}

private struct EmptyFavoritesView: View {
    let onBrowse: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(theme.accent.opacity(0.15)).frame(width: 96, height: 96)
                Image(systemName: "heart")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(theme.accentDeep)
            }
            Text("Пока пусто")
                .font(.serif(24, weight: .regular))
                .tracking(-0.5)
                .foregroundStyle(theme.ink)
            Text("Листай карточки в Swipe — то, что свайпнешь вправо, окажется здесь.")
                .font(.sans(13))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.muted)
                .frame(maxWidth: 240)
            Button(action: onBrowse) {
                Text("В Swipe")
                    .font(.sans(14, weight: .semibold))
                    .foregroundStyle(theme.accentInk)
                    .padding(.horizontal, 22)
                    .frame(height: 46)
                    .background(Capsule().fill(theme.ink))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }
}
