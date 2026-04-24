import SwiftUI

struct SearchView: View {
    @Bindable var appState: AppState
    let repository: DataRepository
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void
    let onOpenStore: (String) -> Void

    @Environment(\.appTheme) private var theme
    @State private var query: String = ""
    @FocusState private var isFocused: Bool

    // `recents` now comes from AppState so it reflects actual user history
    // (persisted between sessions). The hardcoded array the demo shipped with
    // made the section look decorative rather than functional.
    private var recents: [String] { appState.recentSearches }
    private let trending = ["Totême","Vintage 90s","Льняные брюки","Тренч","Shelter","Filippa K","Патриаршие"]

    private var results: [Product] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return repository.products.filter {
            ($0.title + $0.brand + $0.color + $0.category).lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 18)
                .padding(.top, 58)
                .padding(.bottom, 10)

            if query.isEmpty {
                emptyStateContent
            } else {
                resultsContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg.ignoresSafeArea())
        .onAppear { isFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.muted)
                TextField("Бренд, вещь, цвет…", text: $query)
                    .font(.sans(14))
                    .foregroundStyle(theme.ink)
                    .tint(theme.accent)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        // Save the query only when the user actually hits
                        // "search" — avoids polluting the history with every
                        // intermediate keystroke.
                        appState.recordSearch(query)
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            // Glass search bar at the top of the search sheet. A subtle
            // white stroke gives the capsule edge definition against the
            // blurred content it floats over.
            .liquidGlass(in: Capsule(style: .continuous))
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.26), lineWidth: 0.6)
            )

            Button("Отмена", action: onBack)
                .font(.sans(14, weight: .medium))
                .foregroundStyle(theme.ink)
        }
    }

    private var emptyStateContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Only show the "recents" section when the user actually has
                // history. An empty state with just a heading looked broken
                // (it was showing leftover demo chips before, which confused
                // users into thinking the app had searched for them).
                if !recents.isEmpty {
                    HStack {
                        sectionTitle("НЕДАВНЕЕ")
                        Spacer()
                        Button(action: { appState.clearRecentSearches() }) {
                            Text("Очистить")
                                .font(.mono(9, weight: .medium))
                                .tracking(1.4)
                                .foregroundStyle(theme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 14)

                    FlowLayout(spacing: 8) {
                        ForEach(recents, id: \.self) { r in
                            Chip(label: r, isActive: false) {
                                query = r
                                // Re-record so tapping an old chip bumps it to
                                // the top of the list (classic MRU behaviour).
                                appState.recordSearch(r)
                            }
                        }
                    }
                    .padding(.top, 10)
                }

                sectionTitle("СЕЙЧАС ИЩУТ")
                    .padding(.top, recents.isEmpty ? 14 : 28)

                FlowLayout(spacing: 8) {
                    ForEach(trending, id: \.self) { t in
                        Chip(label: t, isActive: false) {
                            query = t
                            appState.recordSearch(t)
                        }
                    }
                }
                .padding(.top, 10)

                sectionTitle("МАГАЗИНЫ")
                    .padding(.top, 30)

                VStack(spacing: 0) {
                    ForEach(repository.stores.prefix(4)) { s in
                        StoreSearchRow(store: s, onOpen: { onOpenStore(s.id) })
                        if s.id != repository.stores.prefix(4).last?.id {
                            Divider().background(theme.line)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 120)
            }
            .padding(.horizontal, 22)
        }
    }

    private var resultsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(results.count) РЕЗУЛЬТАТОВ")
                    .font(.mono(10))
                    .tracking(1.6)
                    .foregroundStyle(theme.muted)
                    .padding(.top, 14)

                if results.isEmpty {
                    Text("Ничего не нашли по «\(query)»")
                        .font(.sans(13))
                        .foregroundStyle(theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 16) {
                        ForEach(results) { p in
                            SearchResultCard(
                                product: p,
                                store: repository.store(id: p.storeId),
                                onTap: { onOpenProduct(p.id) }
                            )
                        }
                    }
                }
                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 22)
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(.mono(10))
            .tracking(1.6)
            .foregroundStyle(theme.muted)
    }
}

private struct StoreSearchRow: View {
    let store: Store
    let onOpen: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                StoreCoverImage(store: store)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.sans(13, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("\(store.vibe) · \(String(format: "%.1f", store.distanceKm)) км")
                        .font(.sans(11))
                        .foregroundStyle(theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.muted)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct SearchResultCard: View {
    let product: Product
    let store: Store?
    let onTap: () -> Void
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                ProductImage(product: product, cornerRadius: 12, showImageId: false)
                    .aspectRatio(3.0/4.0, contentMode: .fit)

                Text("\(product.brand.uppercased()) · \(store?.name.uppercased() ?? "")")
                    .font(.mono(9))
                    .tracking(1.2)
                    .foregroundStyle(theme.muted)
                    .padding(.top, 2)

                Text(product.title)
                    .font(.sans(12, weight: .medium))
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
