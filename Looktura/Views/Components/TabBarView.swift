import SwiftUI
import UIKit

/// Liquid Glass tab bar. The active-tab indicator is a translucent droplet
/// that flows AND morphs between tabs — it stretches along the motion axis
/// mid-flight and settles back to its capsule shape at the destination.
///
/// Three complaints drove the current implementation; each maps to a
/// decision below.
///
/// ## Complaint → fix mapping
///
/// **(1) "Телепортируется, не перетекает"** (teleports instead of flowing).
///     Earlier versions rendered the pill inside whichever cell was
///     active, transported via `glassEffectID` or `matchedGeometryEffect`.
///     Both rely on SwiftUI interpolating a frame between two
///     view-identities that appear in sequence. Reliable for position in
///     theory, but the pill is still conceptually vanishing-and-reappearing
///     — which means a shape-morph applied to it can't carry across the
///     transition (the "in flight" instance doesn't exist).
///
///     Fix: render exactly ONE pill, OUTSIDE the cells, absolute-positioned
///     over the active tab's frame (captured via PreferenceKey from each
///     cell's GeometryReader). The pill is a single view with a continuous
///     identity, so its `.offset` + `.frame` animate smoothly under a
///     spring as `selection` changes — and a `.keyframeAnimator` on the
///     same view can drive a synchronized shape morph during transit.
///
/// **(2) "Капля не меняет форму"** (droplet has no shape animation).
///     Motion alone reads as "digital slide". Mercury/liquid reads as
///     stretch-while-in-motion. `.keyframeAnimator(trigger: selection)`
///     fires a scale-x/scale-y curve on every tab change — scaleX spikes
///     to ~1.22 mid-flight (wide stretch), scaleY dips to ~0.86 (squish),
///     then both settle back to 1.0 at the destination. Combined with the
///     under-damped spring on the pill's frame, this is the mercury
///     droplet the design wanted.
///
/// **(3) "Непрозрачный"** (opaque, not transparent).
///     `.regular` / `.regular.interactive()` glass — which Apple's own
///     Phone/Music tab bars use — is deliberately solid-ish so the
///     selected tab reads as distinct. But this app's visual language
///     leans toward "subtle lift" more than "opaque chip". A Capsule
///     filled with `Color.white.opacity(~0.18)` on top of
///     `.ultraThinMaterial` reads as glass but lets the tab bar's own
///     backdrop show through. The result is a see-through drop.
///
/// **(4) "При зажатии растягивается"** (stretches when pressed).
///     `.glassEffect(.regular.interactive(), ...)` is exactly the API
///     that makes glass *respond to press pressure* — that's the slider
///     thumb behavior where holding your finger down inflates the glass.
///     The user doesn't want that. `.interactive()` is removed. Press
///     feedback, if needed, lives on the tab cell (icon scale), not on
///     the pill.
///
/// ## Animation timing
///
/// * Position spring: `.spring(response: 0.5, dampingFraction: 0.78)` —
///   slightly under-damped so the pill overshoots by a few points and
///   settles back.
/// * Shape morph keyframes: ~0.48s total across three cubic segments,
///   chosen to land at 1.0/1.0 just as the spring settles. The mid-flight
///   stretch peaks at ~0.16s in (roughly when the pill is halfway between
///   tabs) and the final settle is a small overshoot bounce.
///
/// Anything faster than ~0.4s total feels digital-abrupt; anything slower
/// than ~0.6s feels sluggish. 0.5 is the sweet spot for "alive but snappy".
struct LookturaTabBar: View {
    @Binding var selection: Tab
    @Environment(\.appTheme) private var theme
    var badges: [Tab: Int] = [:]

    /// Per-tab frames, captured from each cell's GeometryReader via
    /// preference key. The pill reads the active tab's frame from this
    /// dict and positions itself there. When `selection` changes, the
    /// lookup returns a different CGRect — SwiftUI's spring animates the
    /// frame/offset transition.
    @State private var tabFrames: [Tab: CGRect] = [:]

    private let tabs: [(Tab, String, String)] = [
        (.feed, "Swipe", "swipe"),
        (.catalog, "Каталог", "grid"),
        (.map, "Карта", "map"),
        (.favorites, "Избранное", "heart"),
        (.profile, "Профиль", "user")
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Pill renders BEHIND the cells. If tabFrames is still empty
            // (very first layout pass before preferences flow), skip —
            // the pill will appear as soon as frames are known.
            if let rect = tabFrames[selection] {
                pill
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    // The spring-on-value-change is what makes the
                    // pill's position TRAVEL between tabs rather than
                    // teleport. The value being watched is the resolved
                    // CGRect for the active tab, which changes whenever
                    // selection changes (or, harmlessly, when layout
                    // reports new frames — identical rects skip).
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.78),
                        value: rect
                    )
                    // Hit-testing OFF — the pill is decorative only. The
                    // tap target belongs to the cell beneath it, so when
                    // the pill happens to sit over an inactive cell
                    // during flight, it doesn't eat that cell's tap.
                    .allowsHitTesting(false)
            }

            HStack(spacing: 0) {
                ForEach(tabs, id: \.0) { tab, label, icon in
                    TabCell(
                        tab: tab,
                        label: label,
                        icon: icon,
                        isActive: selection == tab,
                        badge: badges[tab] ?? 0,
                        onTap: {
                            guard selection != tab else { return }
                            UIImpactFeedbackGenerator(style: .soft)
                                .impactOccurred(intensity: 0.7)
                            // Wrap the selection change in a spring so
                            // the @State update that drives keyframe-
                            // animator + all isActive transitions lands
                            // in one coherent transaction.
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                                selection = tab
                            }
                        }
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: TabFramesKey.self,
                                    value: [tab: geo.frame(in: .named("tabbar"))]
                                )
                        }
                    )
                }
            }
        }
        .coordinateSpace(name: "tabbar")
        .onPreferenceChange(TabFramesKey.self) { frames in
            // Merge rather than replace — preferences from individual
            // cells arrive separately and we want to accumulate them.
            tabFrames.merge(frames) { _, new in new }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .liquidGlass(in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 22, x: 0, y: 12)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    /// Active-tab pill. Theme-adaptive translucent chip: `theme.ink` at
    /// ~8–12% opacity gives a dark pill on the ivory theme and a light
    /// pill on the noir theme — in BOTH cases readable on the tab bar's
    /// own liquid-glass capsule without being opaque. An earlier pass
    /// used `white.opacity(0.18)` which read as invisible on light
    /// backgrounds (both the tab bar AND the pill resolved to near-
    /// white on ivory, so the contrast was zero). Key property: the
    /// fill is still low-alpha enough that the backdrop shows through,
    /// so this still reads as glass and not as a solid button.
    ///
    /// The shape morph (stretch-while-flying, settle-at-destination) is
    /// driven by the `.keyframeAnimator` further down, triggered by
    /// `selection`.
    private var pill: some View {
        Capsule(style: .continuous)
            .fill(theme.ink.opacity(0.10))
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(
                // Hairline stroke in the same theme.ink family so the
                // edge is defined in both modes. Gradient from slightly
                // stronger at top (specular highlight reading) to
                // softer at bottom.
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                theme.ink.opacity(0.28),
                                theme.ink.opacity(0.10),
                                theme.ink.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.7
                    )
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            .padding(2)
            // Shape morph during transit. Every `selection` change fires
            // this keyframe sequence. The scale-x peak at the ~0.16s mark
            // lines up with the pill's mid-flight position under the
            // 0.5s-response spring; scale-y dips in the same window so
            // the pill squishes flat while it flies wide. The ~0.04s
            // initial hold lets the spring begin displacing before the
            // stretch kicks in — without it the morph fires a frame too
            // early and reads as a standalone pulse rather than motion-
            // coupled squish.
            .keyframeAnimator(
                initialValue: PillMorph(),
                trigger: selection
            ) { content, m in
                content.scaleEffect(x: m.sx, y: m.sy, anchor: .center)
            } keyframes: { _ in
                KeyframeTrack(\.sx) {
                    CubicKeyframe(1.00, duration: 0.04)
                    CubicKeyframe(1.22, duration: 0.14)   // wide stretch mid-flight
                    CubicKeyframe(1.06, duration: 0.16)   // overshoot relax
                    CubicKeyframe(1.00, duration: 0.14)   // settle
                }
                KeyframeTrack(\.sy) {
                    CubicKeyframe(1.00, duration: 0.04)
                    CubicKeyframe(0.86, duration: 0.14)   // squish during stretch
                    CubicKeyframe(0.97, duration: 0.16)
                    CubicKeyframe(1.00, duration: 0.14)
                }
            }
    }
}

/// Animatable scale pair used by the pill's keyframe morph. Two tracks
/// (sx/sy) are driven independently so the stretch-along-axis and
/// squish-perpendicular happen with slightly different curves — the
/// asymmetry is what sells the mercury feel versus a uniform "pulse".
private struct PillMorph: Equatable {
    var sx: CGFloat = 1.0
    var sy: CGFloat = 1.0
}

/// Preference-key carrier for per-cell frame rectangles. Each `TabCell`
/// publishes its frame (in the tab-bar-local coordinate space) via a
/// `.background(GeometryReader { ... })`, the keys merge at the parent,
/// and the pill reads `tabFrames[selection]` to find where to sit.
private struct TabFramesKey: PreferenceKey {
    static var defaultValue: [Tab: CGRect] = [:]
    static func reduce(
        value: inout [Tab: CGRect],
        nextValue: () -> [Tab: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// One tab cell. No pill rendering inside — the pill lives at the
/// LookturaTabBar level and positions itself over the active cell via
/// preference-published frames.
private struct TabCell: View {
    let tab: Tab
    let label: String
    let icon: String
    let isActive: Bool
    let badge: Int
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    /// Increments only when THIS cell flips to active. SF Symbols use it
    /// as the `value` key so the bounce fires exactly on selection — not
    /// on every selection change elsewhere.
    @State private var selectTick: Int = 0

    var body: some View {
        Button(action: onTap) {
            cellContent
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onChange(of: isActive) { _, nowActive in
            if nowActive { selectTick &+= 1 }
        }
    }

    private var cellContent: some View {
        VStack(spacing: 2) {
            TabIcon(name: icon, active: isActive, bounceTick: selectTick)
                .frame(width: 24, height: 24)
                .scaleEffect(isActive ? 1.12 : 1.0)
                .animation(
                    isActive
                        ? .interpolatingSpring(stiffness: 280, damping: 14)
                        : .easeOut(duration: 0.14),
                    value: isActive
                )

            Text(label)
                .font(.sans(10, weight: isActive ? .semibold : .medium))
                .tracking(0.3)
                .lineLimit(1)
        }
        .foregroundStyle(isActive ? theme.ink : theme.muted)
        .overlay(alignment: .topTrailing) {
            if badge > 0 {
                Text("\(badge)")
                    .font(.sans(9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 16, minHeight: 16)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(theme.accent))
                    .offset(x: 14, y: -2)
            }
        }
    }
}

struct TabIcon: View {
    let name: String
    let active: Bool
    /// Changes only when this tab becomes active. SF Symbols use it as the
    /// `value` key so the bounce fires exactly on selection — not on every
    /// selection change elsewhere.
    var bounceTick: Int = 0

    var body: some View {
        let lineWidth: CGFloat = active ? 2 : 1.6
        Group {
            switch name {
            case "swipe":
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(lineWidth: lineWidth)
                        .frame(width: 14, height: 18)
                    VStack(spacing: 2) {
                        Rectangle().frame(height: lineWidth).frame(width: 8)
                        Rectangle().frame(height: lineWidth).frame(width: 5)
                    }
                    .offset(y: -1)
                }
            case "grid":
                let s: CGFloat = 10
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2).stroke(lineWidth: lineWidth).frame(width: s, height: s)
                        RoundedRectangle(cornerRadius: 2).stroke(lineWidth: lineWidth).frame(width: s, height: s)
                    }
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2).stroke(lineWidth: lineWidth).frame(width: s, height: s)
                        RoundedRectangle(cornerRadius: 2).stroke(lineWidth: lineWidth).frame(width: s, height: s)
                    }
                }
            case "map":
                bounceable(Image(systemName: "map"))
                    .font(.system(size: 18, weight: active ? .semibold : .regular))
            case "heart":
                bounceable(Image(systemName: active ? "heart.fill" : "heart"))
                    .font(.system(size: 18, weight: active ? .semibold : .regular))
            case "user":
                bounceable(Image(systemName: active ? "person.fill" : "person"))
                    .font(.system(size: 18, weight: active ? .semibold : .regular))
            default: EmptyView()
            }
        }
    }

    @ViewBuilder
    private func bounceable(_ image: Image) -> some View {
        if #available(iOS 17.0, *) {
            image.symbolEffect(.bounce, options: .speed(1.4), value: bounceTick)
        } else {
            image
        }
    }
}
