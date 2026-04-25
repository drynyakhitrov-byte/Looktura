import SwiftUI

struct CatalogView: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let onOpenProduct: (String) -> Void

    @Environment(\.appTheme) private var theme

    @State private var selectedCategory: String = "Всё"
    @State private var showFilters: Bool = false
    @State private var columnCount: Int = 2
    @State private var styleFilters: Set<String> = []
    @State private var sizeFilters: Set<String> = []
    @State private var colorFilters: Set<String> = []
    @State private var priceMax: Double = 100_000

    private let priceCeiling: Double = 100_000

    private var filtered: [Product] {
        repository.products.filter { p in
            let categoryOk = selectedCategory == "Всё" || p.category == selectedCategory
            let styleOk = styleFilters.isEmpty || styleFilters.contains(p.style)
            let sizeOk = sizeFilters.isEmpty || p.sizes.contains { $0.a && sizeFilters.contains($0.s) }
            let colorOk = colorFilters.isEmpty || colorFilters.contains(p.color)
            let priceOk = Double(p.price) <= priceMax
            return categoryOk && styleOk && sizeOk && colorOk && priceOk
        }
    }

    /// Count of filters the user has actively engaged. Drives the red badge on
    /// the filter icon + decides whether to render the active-filters strip.
    /// Category is intentionally excluded — it has its own chip row above, so
    /// counting it would double up on what the user already sees.
    private var activeFilterCount: Int {
        styleFilters.count
            + sizeFilters.count
            + colorFilters.count
            + (priceMax < priceCeiling ? 1 : 0)
    }

    private func clearAllFilters() {
        styleFilters.removeAll()
        sizeFilters.removeAll()
        colorFilters.removeAll()
        priceMax = priceCeiling
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 22)
                        .padding(.top, 54)
                        .padding(.bottom, 6)

                    categoriesStrip
                        .padding(.bottom, 12)

                    activeFiltersStrip

                    // Empty-results hint when the current filter set matches
                    // nothing. Surfacing this inline prevents the user from
                    // staring at a blank grid and wondering if the app broke.
                    if filtered.isEmpty {
                        emptyResultsBlock
                            .padding(.horizontal, 22)
                            .padding(.vertical, 40)
                    } else {
                        grid
                            .padding(.horizontal, 18)
                            .padding(.bottom, 120)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .sheet(isPresented: $showFilters) {
            FiltersSheet(
                styleFilters: $styleFilters,
                sizeFilters: $sizeFilters,
                colorFilters: $colorFilters,
                priceMax: $priceMax,
                priceCeiling: priceCeiling,
                onClose: { showFilters = false }
            )
            .presentationDetents([.fraction(0.82), .large])
            .presentationDragIndicator(.visible)
            // Thin material so the blurred catalog grid shows through
            // the filter sheet — matches the rest of the app's glass
            // modals (picker + new-collection).
            .presentationBackground(.thinMaterial)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("КАТАЛОГ")
                    .font(.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(theme.muted)
                Text("Всё в районе")
                    .font(.serif(30, weight: .regular))
                    .tracking(-0.8)
                    .foregroundStyle(theme.ink)
            }
            Spacer()
            HStack(spacing: 8) {
                IconButton(icon: columnCount == 2 ? "square.grid.2x2" : "rectangle.grid.1x2") {
                    columnCount = columnCount == 2 ? 1 : 2
                }
                // Filter button gets a count badge when filters are active so
                // the user can tell at a glance that the grid is filtered —
                // previously applying filters produced no visual signal on the
                // button, which hid the state from them.
                ZStack(alignment: .topTrailing) {
                    IconButton(icon: "slider.horizontal.3") {
                        showFilters = true
                    }
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(.mono(9, weight: .bold))
                            .foregroundStyle(theme.accentInk)
                            .frame(minWidth: 16, minHeight: 16)
                            .padding(.horizontal, 3)
                            .background(Circle().fill(theme.accent))
                            .overlay(
                                Circle().strokeBorder(theme.bg, lineWidth: 1.5)
                            )
                            .offset(x: 3, y: -3)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    /// Horizontal chip row of currently-applied filters. Each chip removes
    /// itself on tap (quick "untag" affordance), with a "Очистить всё"
    /// shortcut on the right when more than one is active. Absent when no
    /// filters are applied — no empty placeholder, no wasted vertical space.
    @ViewBuilder
    private var activeFiltersStrip: some View {
        if activeFilterCount > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(styleFilters).sorted(), id: \.self) { s in
                        ActiveFilterChip(label: s) { styleFilters.remove(s) }
                    }
                    ForEach(Array(sizeFilters).sorted(), id: \.self) { s in
                        ActiveFilterChip(label: "Размер \(s)") { sizeFilters.remove(s) }
                    }
                    ForEach(Array(colorFilters).sorted(), id: \.self) { c in
                        ActiveFilterChip(
                            label: c,
                            swatchHex: hexForColor(c)
                        ) { colorFilters.remove(c) }
                    }
                    if priceMax < priceCeiling {
                        ActiveFilterChip(label: "до \(Int(priceMax).formattedRubles)") {
                            priceMax = priceCeiling
                        }
                    }

                    if activeFilterCount > 1 {
                        Button(action: clearAllFilters) {
                            Text("Очистить всё")
                                .font(.mono(10, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(theme.accentDeep)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
            }
            .padding(.bottom, 12)
        }
    }

    private func hexForColor(_ name: String) -> String {
        Catalog.namedColors.first { $0.name == name }?.hex ?? "#A8A8A8"
    }

    private var emptyResultsBlock: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(theme.muted)
            Text("Ничего не подходит под фильтры")
                .font(.sans(14, weight: .medium))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            Text("Попробуй снять один из фильтров выше или сбрось всё.")
                .font(.sans(12))
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Button(action: clearAllFilters) {
                Text("Сбросить фильтры")
                    .font(.sans(13, weight: .semibold))
                    .foregroundStyle(theme.accentInk)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(theme.ink))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private var categoriesStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Catalog.categories, id: \.self) { c in
                    Chip(label: c, isActive: selectedCategory == c) {
                        selectedCategory = c
                    }
                }
            }
            .padding(.horizontal, 22)
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: columnCount == 2 ? 10 : 14), count: columnCount),
            spacing: 18
        ) {
            ForEach(filtered) { p in
                CatalogCard(
                    product: p,
                    store: repository.store(id: p.storeId),
                    aspect: columnCount == 2 ? 3.0/4.0 : 16.0/11.0
                ) {
                    onOpenProduct(p.id)
                }
            }
        }
    }
}

private struct CatalogCard: View {
    let product: Product
    let store: Store?
    let aspect: CGFloat
    let onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    ProductImage(product: product, cornerRadius: 14, showImageId: false)
                        .aspectRatio(aspect, contentMode: .fit)

                    HStack {
                        if let s = store {
                            // Store-name pill. Was `.white.opacity(0.85)` +
                            // `theme.ink` text — fine in the light theme, but
                            // in the dark theme `theme.ink` is near-white, so
                            // the pill became white-on-white and disappeared
                            // (same bug as SwipeCard's top-left pill pre-fix).
                            // Now uses `theme.surface.opacity(0.88)` + an
                            // ultraThinMaterial blur + a hairline `theme.line`
                            // stroke so it reads as a glass chip in BOTH
                            // themes: white-ish on ivory, near-black on noir,
                            // always contrasting `theme.ink`.
                            Text(s.name.uppercased())
                                .font(.mono(9))
                                .tracking(1.2)
                                .foregroundStyle(theme.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    ZStack {
                                        Capsule().fill(theme.surface.opacity(0.88))
                                        Capsule().fill(.ultraThinMaterial)
                                    }
                                )
                                .overlay(
                                    Capsule().strokeBorder(theme.line, lineWidth: 0.5)
                                )
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if product.hasDiscount {
                            Text("−\(product.discountPercent)%")
                                .font(.mono(10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(theme.danger))
                        }
                    }
                    .padding(10)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(product.brand.uppercased())
                        .font(.mono(9))
                        .tracking(1.3)
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                    Spacer()
                    Text(product.price.formattedRubles)
                        .font(.mono(11, weight: .semibold))
                        .foregroundStyle(theme.ink)
                }

                Text(product.title)
                    .font(.sans(13, weight: .medium))
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Compact removable pill used in the active-filter strip. Leading swatch
/// (for color filters) + label + trailing ✕. Tap anywhere to remove the
/// filter — the whole pill is a button, not just the X, to make it a fat
/// tap target on narrow strips.
private struct ActiveFilterChip: View {
    let label: String
    var swatchHex: String? = nil
    let onRemove: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                if let hex = swatchHex {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(theme.line.opacity(0.6), lineWidth: 0.5))
                }
                Text(label)
                    .font(.mono(10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(theme.accentInk)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.accentInk.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(theme.ink))
        }
        .buttonStyle(.plain)
    }
}

private struct FiltersSheet: View {
    @Binding var styleFilters: Set<String>
    @Binding var sizeFilters: Set<String>
    @Binding var colorFilters: Set<String>
    @Binding var priceMax: Double
    let priceCeiling: Double
    let onClose: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Фильтры")
                        .font(.serif(24, weight: .regular))
                        .tracking(-0.4)
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Button("Сбросить") {
                        styleFilters.removeAll()
                        sizeFilters.removeAll()
                        colorFilters.removeAll()
                        priceMax = priceCeiling
                    }
                    .font(.sans(14))
                    .foregroundStyle(theme.muted)
                }
                .padding(.top, 6)

                sectionTitle("Стиль")
                    .padding(.top, 22)

                FlowLayout(spacing: 8) {
                    ForEach(ProductStyle.allCases) { s in
                        Chip(label: s.rawValue, isActive: styleFilters.contains(s.rawValue)) {
                            toggle(&styleFilters, s.rawValue)
                        }
                    }
                }
                .padding(.top, 10)

                sectionTitle("Размер")
                    .padding(.top, 22)

                FlowLayout(spacing: 8) {
                    ForEach(StandardSize.allCases) { s in
                        Chip(label: s.rawValue, isActive: sizeFilters.contains(s.rawValue)) {
                            toggle(&sizeFilters, s.rawValue)
                        }
                    }
                }
                .padding(.top, 10)

                sectionTitle("Цвет")
                    .padding(.top, 22)

                // Full palette wrap — showed only 8 non-interactive swatches
                // before. Now every catalog color is selectable with a ring +
                // checkmark confirming selection. Wrapping in FlowLayout keeps
                // the grid tidy across iPhone widths without horizontal scroll.
                FlowLayout(spacing: 14) {
                    ForEach(Catalog.namedColors) { c in
                        colorSwatch(c)
                    }
                }
                .padding(.top, 10)

                sectionTitle("Цена до \(Int(priceMax).formattedRubles)")
                    .padding(.top, 22)

                Slider(value: $priceMax, in: 5000...priceCeiling, step: 1000)
                    .tint(theme.ink)
                    .padding(.top, 6)

                PrimaryButton(title: "Показать результаты", action: onClose)
                    .padding(.top, 26)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
        }
        // Soft tint over the thin-material presentation background so
        // the ivory / black palette still reads as distinct.
        .background(theme.bg.opacity(0.35).ignoresSafeArea())
    }

    private func colorSwatch(_ c: NamedColor) -> some View {
        let isSelected = colorFilters.contains(c.name)
        return Button {
            toggle(&colorFilters, c.name)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(hex: c.hex))
                        .frame(width: 36, height: 36)
                    // Selection ring — theme.ink gives the highest-contrast
                    // outline across both ivory and noir themes.
                    Circle()
                        .stroke(
                            isSelected ? theme.ink : theme.line,
                            lineWidth: isSelected ? 2.5 : 1
                        )
                        .frame(width: 36, height: 36)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isLightSwatch(c.hex) ? theme.ink : .white)
                    }
                }
                Text(c.name)
                    .font(.mono(9))
                    .tracking(0.8)
                    .foregroundStyle(isSelected ? theme.ink : theme.muted)
            }
        }
        .buttonStyle(.plain)
    }

    /// Heuristic — light swatches need a dark checkmark to stay visible, dark
    /// swatches need a white one. Uses perceived luminance (Rec 601 coefficients).
    private func isLightSwatch(_ hex: String) -> Bool {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let rgb = Int(s, radix: 16) else { return false }
        let r = Double((rgb >> 16) & 0xFF)
        let g = Double((rgb >> 8) & 0xFF)
        let b = Double(rgb & 0xFF)
        let lum = 0.299 * r + 0.587 * g + 0.114 * b
        return lum > 160
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.mono(10))
            .tracking(1.6)
            .foregroundStyle(theme.muted)
    }

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}
