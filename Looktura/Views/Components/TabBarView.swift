import SwiftUI
import UIKit

/// Liquid Glass tab bar with a floating pill indicator that slides between tabs
/// (Telegram-style). Entire capsule area for each tab is a hit target, not just
/// the icon+label rect.
struct LookturaTabBar: View {
    @Binding var selection: Tab
    @Environment(\.appTheme) private var theme
    @Namespace private var pillNS
    var badges: [Tab: Int] = [:]

    private let tabs: [(Tab, String, String)] = [
        (.feed, "Swipe", "swipe"),
        (.catalog, "Каталог", "grid"),
        (.map, "Карта", "map"),
        (.favorites, "Избранное", "heart"),
        (.profile, "Профиль", "user")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { tab, label, icon in
                TabButton(
                    tab: tab,
                    label: label,
                    icon: icon,
                    isActive: selection == tab,
                    badge: badges[tab] ?? 0,
                    pillNamespace: pillNS,
                    onTap: {
                        guard selection != tab else { return }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) {
                            selection = tab
                        }
                    }
                )
            }
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
}

/// One tab cell. Keeps its own `selectTick` so the bounce + scale pop fires
/// **only** when this specific tab transitions from inactive → active — not
/// every time any selection elsewhere in the bar changes.
private struct TabButton: View {
    let tab: Tab
    let label: String
    let icon: String
    let isActive: Bool
    let badge: Int
    let pillNamespace: Namespace.ID
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    /// Incremented on the `false → true` edge of `isActive`. Icons watch this
    /// tick as their bounce trigger, so only the tab the user just selected
    /// actually animates. The previously-active tab deactivates silently.
    @State private var selectTick: Int = 0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isActive {
                    activePill
                }

                VStack(spacing: 2) {
                    TabIcon(name: icon, active: isActive, bounceTick: selectTick)
                        .frame(width: 24, height: 24)
                        .scaleEffect(isActive ? 1.12 : 1.0)
                        // One-sided spring: pop on activation, snap back on
                        // deactivation (no spring so the outgoing tab doesn't
                        // visibly bounce along with the incoming one).
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
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onChange(of: isActive) { _, nowActive in
            // Bump the tick ONLY on the activation edge — outgoing tab is quiet.
            if nowActive {
                selectTick &+= 1
            }
        }
    }

    // Telegram-style floating glass pill. Lives on the active tab; the
    // matchedGeometryEffect interpolates its position across the bar when the
    // binding changes (parent animates that inside a spring).
    private var activePill: some View {
        Capsule(style: .continuous)
            .fill(Color.white.opacity(0.22))
            .background(
                Capsule(style: .continuous)
                    .fill(theme.ink.opacity(0.06))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
            .matchedGeometryEffect(id: "tabPill", in: pillNamespace)
            .padding(.vertical, 2)
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
