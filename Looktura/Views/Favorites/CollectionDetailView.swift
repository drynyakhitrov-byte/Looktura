import SwiftUI

struct CollectionDetailView: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let collectionId: String
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void
    let onOpenRoute: (String) -> Void

    @Environment(\.appTheme) private var theme
    @State private var showConfirmDelete: Bool = false

    private var collection: FavCollection? {
        appState.collection(id: collectionId)
    }

    private var products: [Product] {
        guard let c = collection else { return [] }
        return c.productIds.compactMap { repository.product(id: $0) }
    }

    private var uniqueStores: [Store] {
        let ids = Array(Set(products.map(\.storeId)))
        return ids.compactMap { repository.store(id: $0) }
    }

    var body: some View {
        Group {
            if let c = collection {
                content(c: c)
            } else {
                // Explicit empty state rather than an auto-pop.
                //
                // The previous implementation was `Color.clear.onAppear { onBack() }`,
                // which silently bounced the user straight back to Favorites
                // any time `collection` resolved to nil — even transiently,
                // during a rebuild, or right after a delete. From the user's
                // perspective this was indistinguishable from "the chip tap
                // did nothing", because the push/pop happened within a single
                // frame: tap → NavigationStack pushes → onAppear pops → user
                // sees a flicker and is back on Favorites.
                //
                // Showing a real empty state instead keeps the navigation
                // visible: if a nil-lookup bug ever recurs, the user (and we)
                // will see the screen rather than a mysterious no-op.
                missingState
            }
        }
    }

    private var missingState: some View {
        ZStack {
            theme.bg.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(theme.muted)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(theme.accent.opacity(0.14)))
                Text("Коллекция не найдена")
                    .font(.serif(22, weight: .regular))
                    .tracking(-0.4)
                    .foregroundStyle(theme.ink)
                Text("Возможно, её удалили или ещё не подгрузили.")
                    .font(.sans(13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: 260)
                Button(action: onBack) {
                    Text("Назад")
                        .font(.sans(14, weight: .semibold))
                        .foregroundStyle(theme.accentInk)
                        .padding(.horizontal, 22)
                        .frame(height: 46)
                        .background(Capsule().fill(theme.ink))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
    }

    private func content(c: FavCollection) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero(c: c)

                    stats(c: c)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)

                    if uniqueStores.count >= 2 {
                        routeBanner(c: c)
                            .padding(.horizontal, 22)
                            .padding(.top, 18)
                    }

                    sectionHeader("ВЕЩИ · \(products.count)")
                        .padding(.horizontal, 22)
                        .padding(.top, 26)

                    grid
                        .padding(.horizontal, 22)
                        .padding(.top, 14)
                        .padding(.bottom, 140)
                }
            }
            .ignoresSafeArea(edges: .top)

            if uniqueStores.count >= 2 {
                stickyCTA(c: c)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
    }

    private func hero(c: FavCollection) -> some View {
        ZStack(alignment: .top) {
            mosaic
                .frame(height: 320)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.20), .clear, .black.opacity(0.65)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)

            VStack {
                HStack {
                    GlassIconButton(icon: "chevron.left", size: 40, action: onBack)
                    Spacer()
                    Menu {
                        Button(role: .destructive) {
                            showConfirmDelete = true
                        } label: {
                            Label("Удалить коллекцию", systemImage: "trash")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            Image(systemName: "ellipsis")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.ink)
                        }
                        .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 60)

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: c.mood.glyph)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(theme.accent))
                        Text(c.mood.label.uppercased())
                            .font(.mono(10))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Text(c.name)
                        .font(.serif(34, weight: .regular))
                        .tracking(-0.8)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
            .frame(height: 320)
        }
        .confirmationDialog(
            "Удалить коллекцию?",
            isPresented: $showConfirmDelete,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                appState.deleteCollection(id: c.id)
                onBack()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вещи останутся в Избранном.")
        }
    }

    private var mosaic: some View {
        Group {
            if products.isEmpty {
                theme.pill
            } else if products.count == 1 {
                ProductImage(product: products[0], cornerRadius: 0, showImageId: false)
            } else if products.count == 2 {
                HStack(spacing: 0) {
                    ProductImage(product: products[0], cornerRadius: 0, showImageId: false)
                    ProductImage(product: products[1], cornerRadius: 0, showImageId: false)
                }
            } else {
                HStack(spacing: 0) {
                    ProductImage(product: products[0], cornerRadius: 0, showImageId: false)
                    VStack(spacing: 0) {
                        ProductImage(product: products[1], cornerRadius: 0, showImageId: false)
                        ProductImage(product: products[2], cornerRadius: 0, showImageId: false)
                    }
                }
            }
        }
    }

    private func stats(c: FavCollection) -> some View {
        HStack(spacing: 10) {
            StatPill(value: "\(products.count)", label: "вещей")
            StatPill(value: "\(uniqueStores.count)", label: uniqueStores.count == 1 ? "магазин" : "магазина")
            StatPill(value: relativeCreated(c.createdAt), label: "создано")
        }
    }

    private func routeBanner(c: FavCollection) -> some View {
        Button {
            onOpenRoute(c.id)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 42, height: 42)
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.accentInk)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("МАРШРУТ")
                        .font(.mono(10))
                        .tracking(1.6)
                        .foregroundStyle(theme.accentDeep)
                    Text("Собрать по \(uniqueStores.count) магазинам")
                        .font(.sans(14, weight: .semibold))
                        .foregroundStyle(theme.ink)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.accentDeep)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.accent.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.accent.opacity(0.35), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.mono(10))
            .tracking(1.6)
            .foregroundStyle(theme.muted)
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 18) {
            ForEach(products) { p in
                CollectionItemCard(
                    product: p,
                    store: repository.store(id: p.storeId),
                    onTap: { onOpenProduct(p.id) },
                    onRemove: { appState.removeFromCollection(productId: p.id, collectionId: collectionId) }
                )
            }
        }
    }

    private func stickyCTA(c: FavCollection) -> some View {
        HStack(spacing: 10) {
            Button {
                onOpenRoute(c.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Построить маршрут")
                        .font(.sans(15, weight: .semibold))
                }
                .foregroundStyle(theme.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(theme.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                colors: [theme.bg.opacity(0), theme.bg],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    private func relativeCreated(_ d: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
        if days < 1 { return "сегодня" }
        if days == 1 { return "вчера" }
        if days < 7 { return "\(days) дн" }
        return "\(days / 7) нед"
    }
}

private struct StatPill: View {
    let value: String
    let label: String
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.serif(22, weight: .regular))
                .tracking(-0.4)
                .foregroundStyle(theme.ink)
            Text(label.uppercased())
                .font(.mono(9))
                .tracking(1.4)
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        // Collection detail stat pills — floating glass tiles.
        .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6)
        )
    }
}

private struct CollectionItemCard: View {
    let product: Product
    let store: Store?
    let onTap: () -> Void
    let onRemove: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ProductImage(product: product, cornerRadius: 14, showImageId: false)
                        .aspectRatio(3.0/4.0, contentMode: .fit)

                    Menu {
                        Button(role: .destructive, action: onRemove) {
                            Label("Убрать из коллекции", systemImage: "minus.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.ink)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .padding(10)
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

                Text(product.price.formattedRubles)
                    .font(.mono(11, weight: .semibold))
                    .foregroundStyle(theme.ink)
            }
        }
        .buttonStyle(.plain)
    }
}
