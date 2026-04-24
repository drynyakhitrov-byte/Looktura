import SwiftUI
import UIKit

/// The app's floating bottom bar. Normally shows `LookturaTabBar`. When the
/// user enters bulk-selection in Favorites (`appState.bulkSelection != nil`),
/// it swaps to `BulkActionBar` — a liquid-glass pill with three actions:
/// cancel, remove from favorites, and "В коллекцию · N".
///
/// The swap is animated with `matchedGeometryEffect` on the capsule shape, so
/// the glass container feels like it morphs from a row of tabs into a row of
/// selection actions. Same shape, same blur, same shadow — only the contents
/// crossfade. This keeps the liquid-glass language consistent and avoids the
/// previous UX where a second floating toolbar collided with the tab bar.
struct BottomBar: View {
    @Bindable var appState: AppState
    let onPickCollection: ([String]) -> Void

    @Namespace private var capsuleNS
    @Environment(\.appTheme) private var theme

    private var inSelection: Bool { appState.isInBulkSelection }

    var body: some View {
        ZStack {
            if inSelection {
                BulkActionBar(
                    count: appState.bulkSelection?.count ?? 0,
                    onCancel: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                            appState.exitBulkSelection()
                        }
                    },
                    onRemoveFavorites: {
                        let ids = Array(appState.bulkSelection ?? [])
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        for id in ids where appState.isFavorite(id) {
                            appState.toggleFavorite(id)
                        }
                        withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) {
                            appState.exitBulkSelection()
                        }
                    },
                    onAddToCollection: {
                        let ids = Array(appState.bulkSelection ?? [])
                        guard !ids.isEmpty else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
                        appState.exitBulkSelection()
                        // Defer by one run-loop tick so the capsule's morph
                        // (tab bar → action bar) finishes its outgoing frame
                        // before the picker sheet slides in on top — prevents
                        // the two animations from stepping on each other.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                            onPickCollection(ids)
                        }
                    },
                    capsuleNamespace: capsuleNS
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.18).delay(0.06)),
                        removal: .opacity.animation(.easeOut(duration: 0.12))
                    )
                )
            } else {
                LookturaTabBar(selection: $appState.selectedTab)
                    .matchedGeometryEffect(id: "bottomBarCapsule", in: capsuleNS)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(.easeOut(duration: 0.18).delay(0.06)),
                            removal: .opacity.animation(.easeOut(duration: 0.12))
                        )
                    )
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: inSelection)
    }
}

/// Liquid-glass pill that replaces the tab bar during bulk selection.
/// Matches the tab bar's capsule geometry, shadow, and stroke so the swap
/// feels like a content change inside a single persistent glass surface.
private struct BulkActionBar: View {
    let count: Int
    let onCancel: () -> Void
    let onRemoveFavorites: () -> Void
    let onAddToCollection: () -> Void
    let capsuleNamespace: Namespace.ID

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            // Cancel (X) — dismiss selection.
            GlassCircleButton(
                icon: "xmark",
                tint: theme.ink,
                action: onCancel
            )
            .accessibilityLabel("Отменить выбор")

            // Primary: "В коллекцию · N". Takes all flexible space.
            Button(action: onAddToCollection) {
                HStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("В коллекцию")
                        .font(.sans(14, weight: .semibold))
                        .tracking(0.2)
                    Text("· \(count)")
                        .font(.mono(12, weight: .semibold))
                        .opacity(0.7)
                        .contentTransition(.numericText())
                }
                .foregroundStyle(theme.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Capsule(style: .continuous).fill(theme.ink)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            // Destructive — remove selection from favorites.
            GlassCircleButton(
                icon: "heart.slash",
                tint: theme.danger,
                action: onRemoveFavorites
            )
            .accessibilityLabel("Убрать из избранного")
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
        .matchedGeometryEffect(id: "bottomBarCapsule", in: capsuleNamespace)
    }
}

/// Small 44pt circle button on glass — matches the tab bar's tab-cell height
/// so the left/right icons line up with the center pill vertically.
private struct GlassCircleButton: View {
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
