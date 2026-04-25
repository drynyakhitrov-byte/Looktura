import SwiftUI
import UIKit

struct SwipeFeedView: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let onOpenDetail: (String) -> Void
    let onOpenSearch: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var stack: [String] = []
    @State private var gone: [(id: String, dir: SwipeDirection)] = []
    @State private var exiting: [ExitingCard] = []
    @State private var drag: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var loaded: Bool = false

    private let threshold: CGFloat = 96
    private let velocityThreshold: CGFloat = 420
    private let rotationDivisor: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if stack.isEmpty && loaded {
                EmptyStackView(onReset: reset)
            } else if !loaded {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tint(theme.accent)
            } else {
                // Two flexible spacers centre the deck+buttons block vertically
                // between the header and the floating BottomBar — instead of
                // pinning to the top with a fixed padding. The leading spacer
                // slightly smaller than the trailing one biases the block
                // toward the lower half of the screen, which is the natural
                // thumb-reach zone on large devices (Pro Max / 17 Pro).
                Spacer(minLength: 12)

                cardStack
                    .padding(.horizontal, 18)

                // Nudge the action row a touch lower so the thumb-zone feels
                // natural without actually shrinking the card — the extra
                // padding here gets absorbed by the bottom Spacer rather than
                // by the deck.
                actionRow
                    .padding(.top, 36)

                Spacer(minLength: 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .task {
            await waitForProducts()
            if !loaded, !repository.products.isEmpty {
                stack = repository.products.map(\.id)
                loaded = true
                ImageCache.shared.prefetch(repository.products.prefix(10).compactMap(\.imageURL))
            }
        }
        .onChange(of: repository.products.count) { _, count in
            guard !loaded, count > 0 else { return }
            stack = repository.products.map(\.id)
            loaded = true
        }
        .onChange(of: stack.count) { _, _ in
            let ahead = Array(stack.prefix(6)).compactMap { repository.product(id: $0)?.imageURL }
            ImageCache.shared.prefetch(ahead)
        }
    }

    private func waitForProducts() async {
        for _ in 0..<40 where repository.products.isEmpty {
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                LookturaLogo(size: 32, showsShadow: false)
                VStack(alignment: .leading, spacing: 2) {
                    Wordmark(size: 12)
                    Text("ТВЕРСКАЯ · 6 МАГАЗИНОВ")
                        .font(.mono(9))
                        .tracking(1.6)
                        .foregroundStyle(theme.muted)
                }
            }
            Spacer()
            IconButton(icon: "magnifyingglass", action: onOpenSearch)
        }
    }

    // MARK: Card stack

    private var visibleIds: [String] { Array(stack.prefix(3)) }

    private var cardStack: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Main stack: back-to-front. The top card is the only one that
                // reads `drag` directly — back cards interpolate toward the
                // next-rest pose via `progress` so the user sees the deck
                // breathe while dragging.
                ForEach(Array(visibleIds.enumerated()).reversed(), id: \.element) { idx, id in
                    cardView(for: id, idx: idx, size: size)
                }

                // Exiting layer: cards that have been swiped off the stack but
                // are still mid-flight. Each has its own @State-animated offset
                // so the throw completes naturally without being yanked from
                // the view tree when the main stack shifts.
                ForEach(exiting) { card in
                    if let product = repository.product(id: card.id) {
                        ExitingCardView(
                            card: card,
                            product: product,
                            store: repository.store(id: product.storeId),
                            size: size,
                            theme: theme,
                            rotationDivisor: rotationDivisor,
                            onDone: { removeExiting(card.id) }
                        )
                        .zIndex(100)
                    }
                }
            }
        }
        .frame(height: 504)
    }

    @ViewBuilder
    private func cardView(for id: String, idx: Int, size: CGSize) -> some View {
        if repository.product(id: id) != nil {
            let isTop = idx == 0
            // Tinder semantics: back cards sit at their rest pose during drag —
            // they don't "preview" the advancement. The rise-up animation only
            // plays when the stack actually shifts after a fly-off, driven by
            // the spring around `stack.removeFirst()`.
            let scale = stackScale(idx)
            let yOff = stackYOffset(idx)
            let op = stackOpacity(idx)

            // Unified view tree for every slot. The old code branched on
            // `isTop` and rendered either a direct `SwipeCard` (with drag +
            // gesture modifiers) OR a `BackCardView` wrapper. When the top
            // card flew off, the second card's view type flipped from
            // `BackCardView` to the direct branch — SwiftUI treated that as
            // unmount + remount, so `scaleEffect(0.94)` vanished and the new
            // tree rendered at `scaleEffect(1.0)` discontinuously. Combined
            // with the insertion transition briefly flashing identity before
            // active, the promoting card read as "shrink, then rise" — the
            // exact bug the user reported.
            //
            // Fix: every slot renders as a `BackCardView` (which isolates
            // scale/yOff/opacity from drag ticks via its own Equatable). Drag
            // translation, rotation, overlay and gesture live on the OUTSIDE
            // and are gated by `isTop`. When the stack reshuffles, the view
            // type is stable → scale interpolates smoothly 0.94 → 1.0.
            BackCardView(
                id: id,
                repository: repository,
                size: size,
                scale: scale,
                yOff: yOff,
                op: op
            )
            .overlay { if isTop { decisionOverlays(drag: drag) } }
            .offset(isTop ? drag : .zero)
            .rotationEffect(.degrees(isTop ? Double(drag.width) / rotationDivisor : 0))
            .onTapGesture { if isTop && !isDragging { onOpenDetail(id) } }
            // Gesture is always attached; `allowsHitTesting(isTop)` gates
            // whether it actually receives touches. Attaching it only to the
            // top view would force another view-type diff on promotion.
            .gesture(dragGesture)
            .allowsHitTesting(isTop)
            .zIndex(Double(3 - idx))
            .transition(
                // Hand-off target for the stack. Removals are identity — the
                // card is already mid-flight on the exiting layer, any extra
                // removal animation here would fight it.
                //
                // Insertions are the "new back-card appears from depth" beat.
                // Earlier iterations had various problems:
                //   1. `.opacity` fade-in → card ghosted for a third of a
                //      second ("врывается полупрозрачной" bug).
                //   2. `.modifier` with 0.85 → 1.0 opacity ramp — better, but
                //      still read as "slight translucency" on the surfacing
                //      card.
                //   3. `.modifier` with scale 0.90 → 1.0 + offset 18 → 0 —
                //      fixed the transparency, but SwiftUI's one-frame render
                //      at identity BEFORE the transition's active state kicks
                //      in caused a brief shrink (identity 1.0 × rest 0.88 →
                //      active 0.90 × rest 0.88 → identity). The user saw a
                //      tiny dip-then-grow, which read as "back card first
                //      shrinks, then properly rises".
                //
                // Current fix: pure y-offset, no scale. Even if SwiftUI briefly
                // renders identity first, the only visible effect is "sits
                // right at rest" before the spring pulls it up from 22pt
                // below — no scale jitter whatsoever. Timing also matches the
                // stack spring so the insertion stays in phase with the
                // promotion shift.
                .asymmetric(
                    insertion: .modifier(
                        active: StackEmergeModifier(active: true),
                        identity: StackEmergeModifier(active: false)
                    ).animation(.spring(response: 0.52, dampingFraction: 0.86)),
                    removal: .identity
                )
            )
        }
    }

    private func stackScale(_ idx: Int) -> CGFloat {
        switch idx {
        case 0: return 1.0
        case 1: return 0.94
        default: return 0.88
        }
    }

    private func stackYOffset(_ idx: Int) -> CGFloat {
        switch idx {
        case 0: return 0
        case 1: return 14
        default: return 26
        }
    }

    private func stackOpacity(_ idx: Int) -> Double {
        // All cards stay fully opaque. Previously back cards were 0.78 / 0.48
        // to fake "depth" — but when a card promoted from idx=1 to idx=0,
        // opacity interpolated 0.78 → 1.0 across the 0.52s spring, and the
        // user read that visible ramp as "the next card is slightly
        // transparent". Depth is communicated purely through scale + y-offset
        // + each card's own shadow (see `stackScale` / `stackYOffset`), which
        // is how Tinder-style stacks actually feel in production apps.
        1.0
    }

    private func decisionOverlays(drag: CGSize) -> some View {
        let likeOp = max(0, min(1, drag.width / 110))
        let nopeOp = max(0, min(1, -drag.width / 110))
        return ZStack {
            DecisionBadge(label: "В ИЗБРАННОЕ", color: theme.success, rotation: -16)
                .opacity(likeOp)
                .padding(.top, 36)
                .padding(.leading, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            DecisionBadge(label: "НЕ МОЁ", color: theme.danger, rotation: 16)
                .opacity(nopeOp)
                .padding(.top, 36)
                .padding(.trailing, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        // The badges are stroke-based RoundedRectangles — cheap per frame, but
        // rotating them alongside the card forced a stroke re-resolve each tick.
        // compositingGroup caches the ZStack into one layer, so the parent's
        // rotation effect transforms a bitmap instead of re-stroking.
        .compositingGroup()
        .allowsHitTesting(false)
    }

    // MARK: Action row

    private var actionRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            SwipeActionButton(
                size: 46,
                filled: false,
                disabled: gone.isEmpty,
                action: undo
            ) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .medium))
            }

            Spacer().frame(width: 22)

            SwipeActionButton(
                size: 64,
                filled: true,
                background: theme.danger,
                action: { swipe(.left) }
            ) {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer().frame(width: 18)

            SwipeActionButton(
                size: 64,
                filled: true,
                background: theme.success,
                action: { swipe(.right) }
            ) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Spacer().frame(width: 22)

            SwipeActionButton(
                size: 46,
                filled: true,
                background: theme.accent,
                disabled: stack.isEmpty,
                action: openDetailOfTop
            ) {
                Image(systemName: "info")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Gestures

    private var dragGesture: some Gesture {
        // Tinder/Twinby-style horizontal-only swipe. The card visibly tracks
        // only the X component of the finger's translation — vertical drift
        // is clamped to zero so the deck reads like "a card on rails" and
        // never lifts, tilts up, or previews an up-fling.
        //
        // Up-swipe was removed entirely (along with its "ХОЧУ МЕРИТЬ" decision
        // badge and exit animation case) because the product no longer offers
        // a super-like; the only dispositions are left (reject) / right (save).
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                isDragging = true
                drag = CGSize(width: v.translation.width, height: 0)
            }
            .onEnded { v in
                isDragging = false
                let tx = v.translation
                let vx = v.predictedEndTranslation.width - tx.width

                let rightIntent = tx.width > threshold || vx > velocityThreshold
                let leftIntent = tx.width < -threshold || vx < -velocityThreshold

                if rightIntent {
                    flyOff(dir: .right, velocity: CGSize(width: vx, height: 0))
                } else if leftIntent {
                    flyOff(dir: .left, velocity: CGSize(width: vx, height: 0))
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        drag = .zero
                    }
                }
            }
    }

    // MARK: Stack mutations

    private func store(for product: Product) -> Store? {
        repository.store(id: product.storeId)
    }

    /// Moves the top card to the exiting layer and collapses the main stack
    /// atomically. The exiting card keeps animating to its off-screen target
    /// on its own; the main stack springs remaining cards up into their new
    /// rest poses at the same time.
    ///
    /// This avoids the old "card yanked mid-flight" bug where `stack.removeFirst()`
    /// at t=0.22s cut off the fly-off animation before the card was offscreen.
    private func flyOff(dir: SwipeDirection, velocity: CGSize = .zero) {
        guard let topId = stack.first, let top = repository.product(id: topId) else { return }

        // Snapshot current drag as the exiting card's starting pose so the
        // hand-off from the main stack to the exiting layer is visually seamless.
        let startDrag = drag
        let card = ExitingCard(
            id: topId,
            direction: dir,
            startDrag: startDrag,
            velocity: velocity
        )

        // Side effects (favorite + haptics) fire immediately — they don't
        // depend on the animation landing.
        if dir == .right {
            if !appState.isFavorite(top.id) {
                appState.toggleFavorite(top.id, fireToast: true)
            }
        }
        UIImpactFeedbackGenerator(style: dir == .left ? .soft : .medium)
            .impactOccurred(intensity: 0.75)
        gone.append((id: topId, dir: dir))

        // Atomic shift. Order matters — see note below.
        //
        //  1. Hand the card off to the exiting layer with its current drag as
        //     the starting pose (fly-off continues seamlessly from where the
        //     finger was).
        //  2. Reset `drag` to .zero NON-ANIMATED. This is the critical step:
        //     when the next card's `isTop` flips to true a moment later, its
        //     `.offset(isTop ? drag : .zero)` and `.rotationEffect(isTop ? … : 0)`
        //     modifiers switch from `.zero` literal to `drag` binding. If drag
        //     still held the release value (e.g. 150px right), the spring that
        //     wraps `stack.removeFirst()` would interpolate the new top's
        //     offset from .zero to drag — producing a visible lateral slide
        //     (the "card coming from the side" bug). Resetting first makes the
        //     binding value already `.zero`, so there is no delta to animate.
        //  3. Collapse the main stack inside a spring → remaining back cards
        //     rise up into their new rest poses with a clean vertical motion.
        exiting.append(card)

        var noAnim = Transaction()
        noAnim.disablesAnimations = true
        withTransaction(noAnim) {
            drag = .zero
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
            _ = stack.removeFirst()
        }
    }

    private func swipe(_ dir: SwipeDirection) {
        // Programmatic swipes from action buttons — simulate a moderate toss.
        let v: CGSize
        switch dir {
        case .left: v = CGSize(width: -900, height: 0)
        case .right: v = CGSize(width: 900, height: 0)
        }
        flyOff(dir: dir, velocity: v)
    }

    private func openDetailOfTop() {
        if let topId = stack.first { onOpenDetail(topId) }
    }

    private func undo() {
        guard let last = gone.popLast() else { return }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
            stack.insert(last.id, at: 0)
        }
        if last.dir == .right {
            if appState.isFavorite(last.id) {
                appState.toggleFavorite(last.id)
            }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
    }

    private func removeExiting(_ id: String) {
        exiting.removeAll { $0.id == id }
    }

    private func reset() {
        stack = repository.products.map(\.id)
        gone.removeAll()
        exiting.removeAll()
    }
}

enum SwipeDirection {
    case left, right
}

/// Describes a card that's been swiped off the main stack and is currently
/// animating to its off-screen destination on the exiting layer.
struct ExitingCard: Identifiable, Equatable {
    let id: String
    let direction: SwipeDirection
    let startDrag: CGSize
    let velocity: CGSize

    static func == (lhs: ExitingCard, rhs: ExitingCard) -> Bool { lhs.id == rhs.id }
}

/// Renders a single mid-flight card. Owns its own `offset` state so the
/// animation to the exit pose completes even if the main stack has already
/// collapsed.
private struct ExitingCardView: View {
    let card: ExitingCard
    let product: Product
    let store: Store?
    let size: CGSize
    let theme: AppTheme
    let rotationDivisor: CGFloat
    let onDone: () -> Void

    @State private var offset: CGSize
    @State private var opacity: Double = 1.0
    @State private var started: Bool = false

    init(
        card: ExitingCard,
        product: Product,
        store: Store?,
        size: CGSize,
        theme: AppTheme,
        rotationDivisor: CGFloat,
        onDone: @escaping () -> Void
    ) {
        self.card = card
        self.product = product
        self.store = store
        self.size = size
        self.theme = theme
        self.rotationDivisor = rotationDivisor
        self.onDone = onDone
        _offset = State(initialValue: card.startDrag)
    }

    var body: some View {
        SwipeCard(product: product, store: store)
            .frame(width: size.width, height: size.height)
            .overlay { badges }
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width) / rotationDivisor))
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear {
                guard !started else { return }
                started = true
                flyToExit()
            }
    }

    private func flyToExit() {
        let exit = computeExitOffset()
        // Slightly-overshooting ease-out: accelerates out of frame like a
        // natural throw. Fade starts late so the card stays solid on-screen
        // for most of the flight.
        withAnimation(.timingCurve(0.22, 1.0, 0.34, 1.0, duration: 0.55)) {
            offset = exit
        }
        withAnimation(.easeIn(duration: 0.22).delay(0.33)) {
            opacity = 0
        }
        // Clean up after the animation lands. `asyncAfter` is safe — the
        // ExitingCardView is still in the tree until `onDone` pulls it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            onDone()
        }
    }

    private func computeExitOffset() -> CGSize {
        // Horizontal-only exit. `startDrag.height` is already 0 (the live drag
        // clamps Y to zero), but we keep the expression explicit so it's
        // obvious the card flies clean off the side rather than drifting
        // diagonally.
        let boostX = max(-1400, min(1400, card.velocity.width * 0.32))
        let screenW = UIScreen.main.bounds.width
        let farX = screenW * 1.4
        switch card.direction {
        case .left:
            return CGSize(width: -farX + boostX, height: 0)
        case .right:
            return CGSize(width: farX + boostX, height: 0)
        }
    }

    private var badges: some View {
        let likeOp = max(0, min(1, offset.width / 110))
        let nopeOp = max(0, min(1, -offset.width / 110))
        return ZStack {
            DecisionBadge(label: "В ИЗБРАННОЕ", color: theme.success, rotation: -16)
                .opacity(likeOp)
                .padding(.top, 36)
                .padding(.leading, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            DecisionBadge(label: "НЕ МОЁ", color: theme.danger, rotation: 16)
                .opacity(nopeOp)
                .padding(.top, 36)
                .padding(.trailing, 22)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .allowsHitTesting(false)
    }
}

private struct DecisionBadge: View {
    let label: String
    let color: Color
    let rotation: Double

    var body: some View {
        Text(label)
            .font(.mono(16, weight: .bold))
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(color, lineWidth: 3)
            )
            .rotationEffect(.degrees(rotation))
    }
}

private struct SwipeActionButton<Content: View>: View {
    let size: CGFloat
    let filled: Bool
    var background: Color? = nil
    var disabled: Bool = false
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            content()
                .foregroundStyle(filled ? .white : theme.ink)
                .frame(width: size, height: size)
                .background {
                    if filled {
                        Circle().fill(background ?? theme.ink)
                    }
                }
                .modifier(SwipeButtonGlass(filled: filled))
                .overlay(
                    Circle().strokeBorder(filled ? Color.clear : Color.white.opacity(0.28), lineWidth: 0.5)
                )
                .contentShape(Circle())
                .shadow(
                    color: Color.black.opacity(filled ? 0.22 : 0.08),
                    radius: filled ? 10 : 6,
                    x: 0,
                    y: filled ? 8 : 3
                )
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.4 : 1.0)
        .disabled(disabled)
    }
}

private struct SwipeButtonGlass: ViewModifier {
    let filled: Bool
    func body(content: Content) -> some View {
        if filled {
            content
        } else {
            content.liquidGlass(in: Circle())
        }
    }
}

/// Static behind-the-top card renderer. Takes only the values that matter for
/// its appearance — `drag` is deliberately NOT threaded through so SwiftUI can
/// skip re-evaluating this view on every gesture tick. That's what keeps the
/// deck looking calm while the top card flies around.
private struct BackCardView: View, Equatable {
    let id: String
    let repository: DataRepository
    let size: CGSize
    let scale: CGFloat
    let yOff: CGFloat
    let op: Double

    static func == (lhs: BackCardView, rhs: BackCardView) -> Bool {
        lhs.id == rhs.id
            && lhs.size == rhs.size
            && lhs.scale == rhs.scale
            && lhs.yOff == rhs.yOff
            && lhs.op == rhs.op
    }

    var body: some View {
        if let product = repository.product(id: id) {
            SwipeCard(product: product, store: repository.store(id: product.storeId))
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .offset(y: yOff)
                .opacity(op)
        }
    }
}

/// Transition modifier used when a brand-new card appears at the back of the
/// stack (because the previous front card flew off). The card "emerges from
/// depth" by sliding up from 22pt below its rest position.
///
/// Pure y-offset — no scale component. Any scale delta, even in a transition,
/// risks the one-frame-identity flash that reads as "back card briefly shrinks
/// before rising" (see call-site comment for the full rabbit-hole). An offset
/// at identity is 0pt, at active is +22pt; if SwiftUI happens to render
/// identity for a frame before activating the transition, the worst case is
/// the card sitting exactly at rest for one frame — invisible to the eye.
///
/// Also no opacity — any fade, however shallow, reads as "slight translucency"
/// (the other bug family we fought in `stackOpacity`). Depth is communicated
/// entirely by geometry: y-offset here, plus each card's own shadow.
private struct StackEmergeModifier: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content.offset(y: active ? 22 : 0)
    }
}

private struct EmptyStackView: View {
    let onReset: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            LookturaLogo(size: 60)
                .padding(.bottom, 8)
            Text("Всё просмотрено")
                .font(.serif(30, weight: .regular))
                .tracking(-0.8)
                .foregroundStyle(theme.ink)
            Text("Новинки появятся завтра.\nИли обнови стопку сейчас.")
                .font(.sans(14))
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.muted)
                .frame(maxWidth: 260)
            PrimaryButton(title: "Начать заново", action: onReset)
                .frame(maxWidth: 220)
                .padding(.top, 8)
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}
