import SwiftUI
import UIKit

struct StoreView: View {
    let repository: DataRepository
    let storeId: String
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void

    @Environment(\.appTheme) private var theme

    @State private var isSharing: Bool = false

    private var store: Store? { repository.store(id: storeId) }
    private var items: [Product] { repository.products(inStore: storeId) }

    var body: some View {
        if let s = store {
            content(s: s)
        } else {
            Color.clear.onAppear { onBack() }
        }
    }

    private func content(s: Store) -> some View {
        // Layer the scrollable hero+body under a separate floating top bar.
        // The old layout stuffed the back/share buttons inside the scroll
        // content via a fixed `.padding(.top, 60)`, which:
        //   • drifted off the safe area on larger devices (16 Pro Max cropped
        //     against the Dynamic Island / rounded corners), and
        //   • put icons over a hero that could be almost-white in light mode,
        //     erasing them.
        // Splitting the button row into a safe-area-aware overlay fixes both
        // by letting SwiftUI handle the top inset per device, and the top
        // scrim below guarantees the black icons read against any cover art.
        // Both back and share buttons now carry the same drop-shadow +
        // hairline-stroke treatment DetailView's HeartBadge uses, so the two
        // sides read at the same depth instead of the share icon floating
        // flat against a light hero.
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    hero(s: s)
                    body(s: s)
                }
            }
            .ignoresSafeArea(edges: .top)

            floatingTopBar
        }
        // Explicit fill matches DetailView's outer frame. Without it the ZStack
        // sized loosely to its content and the floating top bar drifted a few
        // points relative to the DetailView chrome — visible as the back/share
        // icons sitting slightly higher than the back/heart on product pages.
        // With the fill in place SwiftUI resolves the safe-area inset exactly
        // the same way across both screens.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        // Attached here (not on `body`) so the closure can capture the
        // unwrapped `s` — `store` is optional one level up.
        .sheet(isPresented: $isSharing) {
            ShareSheet(items: shareItems(for: s))
        }
    }

    private var floatingTopBar: some View {
        // Shadow on both sides matches the visual weight of DetailView's
        // HeartBadge (which shadows only the right) while keeping left/right
        // symmetric here. Stroke isn't re-applied — GlassIconButton already
        // carries its own hairline, and overlaying another would double it.
        HStack {
            GlassIconButton(icon: "chevron.left", size: 40, action: onBack)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            Spacer()
            GlassIconButton(icon: "square.and.arrow.up", size: 40) {
                isSharing = true
            }
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    // `[Any]` is intentional — UIActivityViewController routes each element
    // by type (String → text, URL → link). compactMap guards the URL init.
    private func shareItems(for s: Store) -> [Any] {
        [s.name, s.addr, URL(string: "https://looktura.io/store/\(s.id)")]
            .compactMap { $0 }
    }

    private func hero(s: Store) -> some View {
        ZStack(alignment: .bottomLeading) {
            StoreCoverImage(store: s)
                .frame(height: 320)
                .clipped()

            // Bottom scrim — already-present darkening for the title block.
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)

            // Top scrim — ensures back/share buttons are visible over a light
            // cover image in ivory theme. Limited to the top ~35% so it doesn't
            // bleed into the store-name title area.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.45), location: 0.0),
                    .init(color: .black.opacity(0.18), location: 0.45),
                    .init(color: .clear, location: 0.75)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(s.vibe.uppercased()) · \(s.district.uppercased())")
                    .font(.mono(10))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.8))
                Text(s.name)
                    .font(.serif(42, weight: .regular))
                    .tracking(-1.3)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
    }

    private func body(s: Store) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                infoPill(text: "● ОТКРЫТ · ДО \(s.openUntil)", color: theme.success)
                infoPill(text: "\(String(format: "%.1f", s.distanceKm)) км · \(s.walkingMinutes) мин пешком", color: theme.ink)
            }
            .padding(.top, 20)

            Text(s.bio)
                .font(.sans(15))
                .lineSpacing(4)
                .foregroundStyle(theme.ink)
                .padding(.top, 18)

            VStack(spacing: 0) {
                StoreInfoRow(label: "Адрес", value: s.addr)
                Divider().background(theme.line)
                StoreInfoRow(label: "Часы", value: s.hours)
                Divider().background(theme.line)
                StoreInfoRow(label: "Бренды", value: s.brands.joined(separator: " · "))
            }
            .padding(16)
            // Store info panel — a distinct card floating over the page.
            // Liquid glass reads naturally against the hero gradient
            // spilling into the scroll area.
            .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
            )
            .padding(.top, 18)

            HStack(spacing: 10) {
                Button(action: {}) {
                    Text("Построить маршрут")
                        .font(.sans(13, weight: .semibold))
                        .foregroundStyle(theme.accentInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Capsule().fill(theme.ink))
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Text("Позвонить")
                        .font(.sans(13, weight: .semibold))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(Capsule().stroke(theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)

            HStack(alignment: .firstTextBaseline) {
                Text("В наличии")
                    .font(.serif(22, weight: .regular))
                    .tracking(-0.4)
                    .foregroundStyle(theme.ink)
                Spacer()
                Text("\(items.count) ВЕЩЕЙ")
                    .font(.mono(10))
                    .tracking(1.5)
                    .foregroundStyle(theme.muted)
            }
            .padding(.top, 30)
            .padding(.bottom, 14)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 18) {
                ForEach(items) { p in
                    StoreGridItem(product: p) {
                        onOpenProduct(p.id)
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .padding(.horizontal, 22)
    }

    private func infoPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.mono(10))
            .tracking(1.4)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            // Floating chip over the hero-to-body transition. Glass +
            // hairline stroke keeps them legible across both themes.
            .liquidGlass(in: Capsule(style: .continuous))
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.5)
            )
    }
}

private struct StoreInfoRow: View {
    let label: String
    let value: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.sans(12))
                .foregroundStyle(theme.muted)
            Spacer()
            Text(value)
                .font(.sans(12, weight: .medium))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 220, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

private struct StoreGridItem: View {
    let product: Product
    let onTap: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ProductImage(product: product, cornerRadius: 12, showImageId: false)
                    .aspectRatio(3/4, contentMode: .fit)

                Text(product.brand.uppercased())
                    .font(.mono(9))
                    .tracking(1.2)
                    .foregroundStyle(theme.muted)
                    .padding(.top, 2)

                Text(product.title)
                    .font(.sans(13, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(product.price.formattedRubles)
                    .font(.mono(12, weight: .semibold))
                    .foregroundStyle(theme.ink)
            }
        }
        .buttonStyle(.plain)
    }
}

/// SwiftUI bridge for `UIActivityViewController`. Kept private to this file —
/// promote to `Views/Components/` when a second caller appears.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
