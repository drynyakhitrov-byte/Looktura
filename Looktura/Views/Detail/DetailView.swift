import SwiftUI

struct DetailView: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let productId: String
    let onBack: () -> Void
    let onOpenStore: (String) -> Void
    let onOpenRelated: (String) -> Void
    let onBook: (String) -> Void

    @Environment(\.appTheme) private var theme
    @State private var selectedSize: String = ""
    /// Carousel page inside the hero. Bound to the TabView so swipes update
    /// both the image and the pager dots at the bottom of the hero.
    @State private var galleryIndex: Int = 0
    /// Active fullscreen page when the user taps the hero. Nil = closed.
    @State private var fullscreenStart: Int? = nil

    private var product: Product? {
        repository.product(id: productId)
    }

    private var store: Store? {
        guard let p = product else { return nil }
        return repository.store(id: p.storeId)
    }

    var body: some View {
        if let p = product, let s = store {
            content(p: p, s: s)
                .onAppear {
                    if selectedSize.isEmpty {
                        selectedSize = p.availableSizes.first?.s ?? ""
                    }
                }
        } else {
            Color.clear.onAppear { onBack() }
        }
    }

    private func content(p: Product, s: Store) -> some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    heroBlock(p: p)
                    scrollBody(p: p, s: s)
                        .padding(.bottom, 140)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Top chrome floats separately from the scroll content — respects
            // the system safe-area on every device class (Pro Max / Dynamic
            // Island) without us hand-tuning paddings.
            floatingTopBar(p: p)

            stickyCTA(p: p, s: s)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .fullScreenCover(isPresented: fullscreenBinding) {
            FullscreenGallery(
                urls: p.galleryURLs,
                startIndex: fullscreenStart ?? galleryIndex,
                onClose: { fullscreenStart = nil }
            )
        }
    }

    private var fullscreenBinding: Binding<Bool> {
        Binding(
            get: { fullscreenStart != nil },
            set: { open in if !open { fullscreenStart = nil } }
        )
    }

    private func floatingTopBar(p: Product) -> some View {
        HStack {
            GlassIconButton(icon: "chevron.left", size: 40, action: onBack)
            Spacer()
            // Unified favorite affordance — same red-on-glass badge used in
            // Favorites, so "saved" reads identically across the app instead
            // of morphing into a black-filled glyph only here.
            HeartBadge(
                size: 40,
                isFilled: appState.isFavorite(p.id),
                action: { appState.toggleFavorite(p.id, fireToast: true) }
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    /// Hero is a horizontal TabView so the user can swipe through the product's
    /// gallery. Tapping any slide lifts the selection into the full-screen
    /// `FullscreenGallery` where they can zoom + pan the photo.
    ///
    /// The tap site is a `Button` rather than an `.onTapGesture`. Reason: the
    /// old `.onTapGesture` sometimes competed with the TabView's page-swipe
    /// gesture — a quick swipe was getting consumed as a tap (opening the
    /// full-screen gallery at the wrong page) and slow drags were landing on
    /// the wrong slide. `Button` defers to the system scroll gesture by
    /// design, so swipe-vs-tap disambiguation happens at UIKit's gesture
    /// recognizer level rather than inside SwiftUI's custom-gesture plumbing.
    private func heroBlock(p: Product) -> some View {
        let urls = p.galleryURLs
        return ZStack(alignment: .bottom) {
            TabView(selection: $galleryIndex) {
                ForEach(urls.indices, id: \.self) { idx in
                    Button {
                        fullscreenStart = idx
                    } label: {
                        ZStack {
                            Color.black.opacity(0.06) // canvas behind the fit area
                            CachedImage(url: urls[idx], contentMode: .fill) {
                                // Fall back to the "primary" ProductImage so
                                // the first paint doesn't flash a blank rect.
                                ProductImage(product: p, cornerRadius: 0, showImageId: false)
                            }
                            .clipped()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 560)
            .ignoresSafeArea(edges: .top)

            // Bottom padding clears the scrollBody's `-28pt` rounded-top
            // overlap plus a breathing gap. The old 24pt placed the dots
            // INSIDE the rounded transition — the bottom half of the capsules
            // was getting clipped by the sheet, which is what the user meant
            // by "обрезанный и не виден".
            pageDots(count: urls.count, active: galleryIndex)
                .padding(.bottom, 54)
        }
        .frame(height: 560)
    }

    /// Gallery page indicator. Sits on a dark glass pill so it reads over
    /// light linen shots and dark leather alike, and is sized large enough
    /// (8pt dots, 24pt active) to be legible at a glance rather than fading
    /// into the photo.
    private func pageDots(count: Int, active: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == active ? Color.white : Color.white.opacity(0.55))
                    .frame(width: i == active ? 24 : 8, height: 8)
                    .animation(.easeOut(duration: 0.25), value: active)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        // Dark tint first, then `.ultraThinMaterial` — stacking this way gives
        // the pill enough body to stay visible over blown-out product photos
        // while still refracting the image beneath. A pure material without
        // the dark tint disappeared on light backgrounds.
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.24))
        )
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.28), radius: 10, y: 3)
    }

    private func scrollBody(p: Product, s: Store) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(p.brand.uppercased())
                        .font(.mono(10))
                        .tracking(1.8)
                        .foregroundStyle(theme.muted)
                    Spacer()
                    FreshDot(hours: p.freshHours)
                }

                Text(p.title)
                    .font(.serif(30, weight: .regular))
                    .tracking(-0.7)
                    .foregroundStyle(theme.ink)
                    .padding(.top, 6)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(p.price.formattedRubles)
                        .font(.mono(22, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    if let old = p.oldPrice {
                        Text(old.formattedRubles)
                            .font(.mono(14))
                            .foregroundStyle(theme.muted)
                            .strikethrough()
                    }
                }
                .padding(.top, 12)
            }

            storeCard(s: s)
                .padding(.top, 20)

            sizesBlock(p: p, s: s)
                .padding(.top, 24)

            detailsBlock(p: p)
                .padding(.top, 24)

            alsoAtStore(p: p, s: s)
                .padding(.top, 26)
        }
        .padding(.top, 24)
        .padding(.horizontal, 22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(theme.bg)
                .ignoresSafeArea(edges: .bottom)
                .offset(y: -28)
        )
    }

    private func storeCard(s: Store) -> some View {
        Button {
            onOpenStore(s.id)
        } label: {
            HStack(spacing: 12) {
                Text(String(s.name.prefix(2)).uppercased())
                    .font(.mono(13, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(theme.accentInk)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(theme.accent))

                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name)
                        .font(.sans(14, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("\(s.addr) · \(String(format: "%.1f", s.distanceKm)) км")
                        .font(.sans(12))
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                }

                Spacer()

                Text("● ОТКРЫТ ДО \(s.openUntil)")
                    .font(.mono(9))
                    .tracking(1.4)
                    .foregroundStyle(theme.success)
            }
            .padding(14)
            // Store card floats on the scroll body that already blurs
            // the hero image. Liquid glass gives it a real refractive
            // feel instead of the flat surface fill it had before.
            .liquidGlassInteractive(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    private func sizesBlock(p: Product, s: Store) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("РАЗМЕР · НАЛИЧИЕ В \(s.name.uppercased())")
                .font(.mono(10))
                .tracking(1.6)
                .foregroundStyle(theme.muted)

            FlowLayout(spacing: 8) {
                ForEach(p.sizes) { sz in
                    SizeChip(
                        label: sz.s,
                        available: sz.a,
                        selected: selectedSize == sz.s,
                        minWidth: 52,
                        height: 52,
                        cornerRadius: 14
                    ) {
                        if sz.a { selectedSize = sz.s }
                    }
                }
            }
        }
    }

    private func detailsBlock(p: Product) -> some View {
        VStack(spacing: 0) {
            DetailRow(label: "Цвет", value: p.color)
            Divider().background(theme.line)
            DetailRow(label: "Стиль", value: p.style)
            Divider().background(theme.line)
            DetailRow(label: "Категория", value: p.category)
            Divider().background(theme.line)
            DetailRow(label: "Обновлено", value: "\(p.freshHours) ч назад")
        }
        .padding(18)
        // Product details block — glass panel with a hairline stroke.
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }

    private func alsoAtStore(p: Product, s: Store) -> some View {
        let items = repository.products
            .filter { $0.storeId == s.id && $0.id != p.id }
            .prefix(4)

        return VStack(alignment: .leading, spacing: 12) {
            Text("ЕЩЁ В \(s.name.uppercased())")
                .font(.mono(10))
                .tracking(1.6)
                .foregroundStyle(theme.muted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(items), id: \.id) { x in
                        MiniProductCard(product: x) {
                            // Push the tapped product onto the nav stack via
                            // the handler wired by RootView — this is what
                            // makes the "More in store" row navigable.
                            onOpenRelated(x.id)
                        }
                    }
                }
            }
        }
    }

    private func stickyCTA(p: Product, s: Store) -> some View {
        HStack(spacing: 10) {
            // Same red-on-glass heart the Favorites grid uses. Previously this
            // site used an ink-colored heart with a theme.line stroke, drifting
            // from the rest of the app's visual language for "saved".
            HeartBadge(
                size: 54,
                isFilled: appState.isFavorite(p.id),
                action: { appState.toggleFavorite(p.id, fireToast: true) }
            )

            PrimaryButton(title: "Забронировать примерку", trailingArrow: true) {
                onBook(p.id)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [theme.bg.opacity(0), theme.bg.opacity(0.55), theme.bg.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack {
            Text(label)
                .font(.sans(13))
                .foregroundStyle(theme.muted)
            Spacer()
            Text(value)
                .font(.sans(13, weight: .medium))
                .foregroundStyle(theme.ink)
        }
        .padding(.vertical, 10)
    }
}

struct SizeChip: View {
    let label: String
    let available: Bool
    let selected: Bool
    var minWidth: CGFloat = 46
    var height: CGFloat = 46
    var cornerRadius: CGFloat = 14
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.mono(14, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(selected ? theme.accentInk : (available ? theme.ink : theme.muted))
                .strikethrough(!available)
                .frame(minWidth: minWidth, minHeight: height)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(selected ? theme.ink : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(selected ? theme.ink : theme.line, lineWidth: 1)
                )
                .opacity(available ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!available)
    }
}

struct MiniProductCard: View {
    let product: Product
    var onTap: () -> Void = {}
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ProductImage(product: product, cornerRadius: 12, showImageId: false)
                    .frame(width: 130, height: 160)
                Text(product.title)
                    .font(.sans(12, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: 130, alignment: .leading)
                Text(product.price.formattedRubles)
                    .font(.mono(11))
                    .foregroundStyle(theme.muted)
            }
            .frame(width: 130, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
