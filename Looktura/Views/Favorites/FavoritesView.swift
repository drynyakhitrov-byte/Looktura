import SwiftUI

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
        // `collectionsStrip` is LIFTED OUT of the outer vertical ScrollView on
        // purpose. On real iPhone 16 Pro Max (iOS 26.4) a horizontal strip
        // nested inside a vertical ScrollView suffers gesture-arbitration
        // failures that the simulator does not reproduce: horizontal pans
        // and taps on the mini-cards both get swallowed by the outer pan
        // recogniser even though `UIKitTap` bypasses SwiftUI gestures
        // entirely. Giving the strip its own gesture context — by placing
        // it in the outer VStack *above* the ScrollView — removes the
        // outer pan from the arbitration tree for that region entirely,
        // and taps + horizontal pans both fire reliably on device.
        //
        // Trade-off: the strip is now sticky rather than scrolling away
        // with the page. That is actually desirable UX (the filters stay
        // reachable while browsing the grid) and matches the "Apple Music
        // library" pattern users already know.
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 58)

            collectionsStrip
                .padding(.top, 16)
                .padding(.bottom, 6)
                // Animate only the strip's own selection-mode dim so the
                // outer VStack's gesture tree isn't re-resolved on every
                // selection toggle (previously `.animation` was applied
                // on the entire body, which could re-install gesture
                // recognisers mid-interaction).
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isSelectionMode)

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
                        }
                    }
                }
            }
            // Scope the two body-level animations to the scrolling content
            // where `isSelectionMode` / `selectedIds` actually drive visual
            // changes. Keeping them off the outer VStack prevents the
            // strip's gesture recognisers from being re-resolved when
            // selection state changes elsewhere.
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isSelectionMode)
            .animation(.easeOut(duration: 0.18), value: selectedIds)
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

    /// Horizontally-scrolling strip of mini collection cards. Replaces the
    /// older capsule-chip row — the chips were too visually quiet (the user
    /// described them as "kind of like buttons at the top"), so we promoted
    /// them to proper mini-cards that read at a glance.
    ///
    /// Anatomy of each card (140×90):
    ///   • Top row: a round "glyph puck" on the left + count on the right
    ///   • Bottom:  collection name (one line, truncated)
    ///
    /// Visual language:
    ///   • Active:   filled with a diagonal gradient built from the
    ///               collection's accent (or `theme.accent` for "Все" /
    ///               legacy collections without custom styling); ink-tinted
    ///               shadow and 1pt strokeBorder in the accent color.
    ///   • Inactive: `liquidGlass` surface with a hairline white stroke —
    ///               same material language as the rest of the app.
    ///   • "Новая":  dashed-outline empty card with a plus icon — matches
    ///               the "add a card" treatment from the design handoff.
    private var collectionsStrip: some View {
        // Intentionally NO `.disabled(isSelectionMode)` and NO blanket
        // `.opacity(...)` on the ScrollView itself. Both affect the
        // ScrollView's gesture layer and/or compositing in ways that
        // interact badly with the mini-cards' UIKit tap recognisers on
        // real iPhone 16 Pro Max (iOS 26.4). The per-card dim below
        // gives the same visual cue without touching the scroll's
        // gesture tree.
        //
        // Tapping a mini-card while in selection mode is harmless: it
        // just filters the grid underneath, which is itself greyed out
        // during selection.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                collectionMiniCard(
                    id: nil,
                    name: "Все",
                    count: allFavorited.count,
                    glyph: "heart.fill",
                    customGlyph: nil,
                    customAccentHex: nil
                )

                ForEach(appState.collections) { c in
                    collectionMiniCard(
                        id: c.id,
                        name: c.name,
                        count: c.productIds.count,
                        glyph: c.mood.glyph,
                        customGlyph: c.customEmoji,
                        customAccentHex: c.customAccentHex
                    )
                }

                newCollectionMiniCard
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 4)
            // Dim the cards (not the scroll view). Applied to the HStack
            // keeps hit-testing clean — SwiftUI still composites the
            // strip normally and the ScrollView's pan recogniser stays
            // untouched.
            .opacity(isSelectionMode ? 0.5 : 1.0)
        }
    }

    /// Single mini-card. See `CollectionMiniCard` struct doc comment (below
    /// in the same file) for the full five-attempt gesture-arbitration
    /// story — tl;dr a plain SwiftUI `Button` + `.buttonStyle(.plain)`
    /// works once the strip is lifted out of the outer vertical
    /// ScrollView (see `body`).
    private func collectionMiniCard(
        id: String?,
        name: String,
        count: Int,
        glyph: String,
        customGlyph: String?,
        customAccentHex: String?
    ) -> some View {
        let isActive = selectedCollectionId == id
        let accent: Color = {
            if let hex = customAccentHex, !hex.isEmpty {
                return Color(hex: hex)
            }
            return theme.accent
        }()
        let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return CollectionMiniCard(
            id: id,
            name: name,
            count: count,
            glyph: glyph,
            customGlyph: customGlyph,
            accent: accent,
            isActive: isActive,
            theme: theme,
            cardShape: cardShape,
            onTap: {
                // Tapping a mini-card only swaps the active filter. The
                // dedicated "open the collection page" affordance lives on
                // the hero block (`heroCollection`'s arrow.up.right button),
                // so a single tap here doesn't simultaneously filter AND
                // navigate — which was disorienting because the user got
                // both a list rewrite and a push transition from one gesture.
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    selectedCollectionId = id
                }
            }
        )
    }

    /// Dashed "Новая" card that sits at the end of the strip. Same
    /// plain-view gesture strategy as `CollectionMiniCard` (see that
    /// struct's doc comment for why we moved off `Button`).
    private var newCollectionMiniCard: some View {
        NewCollectionMiniCard(
            theme: theme,
            onTap: onCreateNewCollection
        )
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
        .scaleEffect(isSelected ? 0.96 : (isPressed ? 0.975 : 1.0))
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        // Long-press duration was 0.35s — felt sluggish on phone (the
        // "I'm pressing but nothing's happening" moment of uncertainty).
        // 0.22s is right at the edge of "intentional hold" without
        // dragging interactions into false positives; the press-scale
        // animation provides visual feedback the instant the finger lands
        // so the user never wonders if the tap registered.
        .onLongPressGesture(
            minimumDuration: 0.22,
            maximumDistance: 30,
            perform: { onLongPress() },
            onPressingChanged: { pressing in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                    isPressed = pressing
                }
            }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.76), value: isSelected)
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: isSelectionMode)
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

/// Mini-card cell for the collections strip. Lives outside FavoritesView so
/// its gesture state doesn't cause the parent view to recompute the whole
/// strip on every press.
///
/// ## Gesture implementation history (read this before "fixing" it)
///
/// We've now tried FIVE approaches. The current (Attempt 5) is the one
/// that works on real iPhone 16 Pro Max (iOS 26.4):
///
///   **Attempt 1:** `.onTapGesture` + `.onLongPressGesture(onPressingChanged:)`
///   The long-press recogniser claims the touch immediately (to report
///   press-began). On iOS 26 the arbiter then starves the parent
///   ScrollView's pan, so taps are lost AND scroll-by-drag is lost too.
///
///   **Attempt 2:** `Button` + `ButtonStyle` with the strip **inside** the
///   outer vertical `ScrollView`. Button defers its touch capture to
///   cooperate with an enclosing ScrollView — textbook fix in theory. In
///   practice, with two nested ScrollViews (outer vertical + inner
///   horizontal), the arbiter handed the touch to the *outer* pan on the
///   slightest finger motion and Button's deferred claim never won.
///
///   **Attempt 3:** plain view + `.onTapGesture`.
///   SwiftUI's own gesture. Simulator worked; device still missed taps
///   because the outer vertical ScrollView was consuming touches before
///   the tap recogniser could resolve.
///
///   **Attempt 4:** SwiftUI visual content + UIKit tap recogniser via
///   `UIKitTap` (`UIViewRepresentable`). A transparent `UIView` sibling
///   was overlaid on the card's full rect with a bare
///   `UITapGestureRecognizer` attached. The UIView's `hitTest` returned
///   `self` unconditionally, which on iOS 26 stole touches not just from
///   the card's own SwiftUI gestures but also from the enclosing
///   SwiftUI ScrollView — so horizontal scrolling over a card
///   disappeared entirely. Taps still failed on device because the
///   outer vertical ScrollView's pan started winning as soon as the
///   finger moved a pixel, and the UIView's `cancelsTouchesInView =
///   false` didn't help when the ancestor pan was a *SwiftUI* gesture
///   rather than a UIKit `UIPanGestureRecognizer`.
///
///   **Attempt 5 (this version):** `Button` + `.buttonStyle(.plain)`,
///   and the horizontal strip is **LIFTED OUT** of the outer vertical
///   `ScrollView` (see `FavoritesView.body`). With only the strip's own
///   horizontal `ScrollView` in the gesture tree above the card, the
///   arbiter no longer has an outer vertical pan to hand off to, and
///   Button's deferred-touch capture works exactly the way it does in
///   `CatalogView`'s `categoriesStrip` (which has used the same
///   `Button` + `.buttonStyle(.plain)` pattern since day one, and taps
///   cleanly on device).
///
///   Takeaway: the root cause was always the nested-ScrollView
///   arbitration, not the tap mechanism. Fancy UIKit bridges were
///   treating the symptom. Lifting the strip fixes the structural cause
///   and the simplest SwiftUI primitive then works.
///
/// The `FavoriteCard` in the vertical grid keeps its own SwiftUI
/// long-press gesture because it genuinely needs it (enter bulk
/// selection) and the vertical-parent + tap-child pairing doesn't
/// trigger the same arbitration pathology.
private struct CollectionMiniCard: View {
    let id: String?
    let name: String
    let count: Int
    let glyph: String
    let customGlyph: String?
    let accent: Color
    let isActive: Bool
    let theme: AppTheme
    let cardShape: RoundedRectangle
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(isActive
                                  ? theme.accentInk.opacity(0.25)
                                  : accent.opacity(0.20))
                        if let cg = customGlyph, !cg.isEmpty {
                            Text(cg)
                                .font(.serif(14, weight: .regular))
                                .foregroundStyle(isActive ? theme.accentInk : accent)
                        } else {
                            Image(systemName: glyph)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isActive ? theme.accentInk : accent.opacity(0.95))
                        }
                    }
                    .frame(width: 30, height: 30)

                    Spacer(minLength: 0)

                    Text("\(count)")
                        .font(.mono(11, weight: .semibold))
                        .foregroundStyle((isActive ? theme.accentInk : theme.ink).opacity(0.75))
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 0)

                Text(name)
                    .font(.sans(13, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(isActive ? theme.accentInk : theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(12)
            .frame(width: 140, height: 90, alignment: .topLeading)
            .background {
                // Active: saturated accent gradient.
                // Inactive: plain theme-tinted translucent fill — explicitly
                // NOT `liquidGlass`. `.glassEffect` installs a hit-testing
                // material that can compete with gesture arbitration inside a
                // horizontal scroll; a solid translucent fill gives the same
                // visual language without the gesture cost.
                if isActive {
                    cardShape.fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                } else {
                    cardShape.fill(theme.surface.opacity(0.55))
                }
            }
            .overlay(
                cardShape
                    .strokeBorder(
                        isActive ? accent.opacity(0.55) : theme.line,
                        lineWidth: isActive ? 1 : 0.5
                    )
            )
            .shadow(
                color: isActive ? accent.opacity(0.32) : Color.black.opacity(0.06),
                radius: isActive ? 14 : 6,
                x: 0,
                y: isActive ? 8 : 3
            )
            // `.contentShape` on the CARD guarantees the full 140×90 rect is
            // hit-testable — no transparent gaps between the glyph puck,
            // counter, and name where a tap could fall through.
            .contentShape(cardShape)
        }
        .buttonStyle(.plain)
    }
}

/// Dashed-outline "new collection" card. Same `Button` + `.buttonStyle(.plain)`
/// pattern as `CollectionMiniCard` — see that struct's doc comment for the
/// full history of why we landed here.
private struct NewCollectionMiniCard: View {
    let theme: AppTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.18))
                            .frame(width: 30, height: 30)
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.accentDeep)
                    }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                Text("Новая")
                    .font(.sans(13, weight: .semibold))
                    .foregroundStyle(theme.accentDeep)
            }
            .padding(12)
            .frame(width: 140, height: 90, alignment: .topLeading)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        theme.accent.opacity(0.6),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
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

