import Foundation
import Observation
import SwiftUI

enum Tab: String, Hashable {
    case feed, catalog, map, favorites, profile
}

enum Route: Hashable {
    case detail(productId: String)
    case store(storeId: String)
    case booking(productId: String)
    case bookingConfirmed(productId: String, size: String, date: Date, time: String)
    case collectionDetail(collectionId: String)
    case routeBuilder(collectionId: String?)
    case pickCollection(productIds: [String])
    case newCollection(seedProductIds: [String])
    case search
    case notifications
}

struct FavoriteToast: Equatable {
    let productId: String
    let issuedAt: Date
}

@Observable
final class AppState {
    var themeKey: AppThemeKey {
        didSet {
            UserDefaults.standard.set(themeKey.rawValue, forKey: "themeKey")
        }
    }

    var theme: AppTheme { AppTheme.theme(for: themeKey) }

    var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "onboardingDone")
        }
    }

    var selectedTab: Tab = .feed
    var favorites: Set<String> = [] {
        didSet { persistFavorites() }
    }
    var bookings: [Booking] = []
    var quizPicks: QuizPicks = QuizPicks()

    var collections: [FavCollection] = [] {
        didSet { persistCollections() }
    }

    var pendingToast: FavoriteToast? = nil

    /// MRU list of search queries the user has actually submitted. Persisted
    /// between launches so the "Недавнее" section on SearchView reflects real
    /// history instead of a hardcoded demo array. Capped to a short list so
    /// the chip row doesn't blow out on long sessions.
    var recentSearches: [String] = [] {
        didSet { persistRecentSearches() }
    }

    /// Active bulk selection in Favorites. `nil` means the user is not in
    /// selection mode; any non-nil value (including an empty set) means the
    /// bottom bar should show the bulk action pill instead of the tab bar.
    ///
    /// Lives on `AppState` rather than inside `FavoritesView` so `RootView`
    /// can morph the tab bar capsule into the action capsule (liquid-glass
    /// matched-geometry transition) without having to reach into child state.
    var bulkSelection: Set<String>? = nil

    struct QuizPicks {
        var styles: Set<String> = []
        var sizes: Set<String> = []
        var budget: String = "15–40k"
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "themeKey"),
           let key = AppThemeKey(rawValue: raw) {
            self.themeKey = key
        } else {
            self.themeKey = .ivory
        }
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboardingDone")
        self.collections = loadCollections()
        self.favorites = loadFavorites()
        self.recentSearches = loadRecentSearches()
    }

    // MARK: Favorites

    func toggleFavorite(_ id: String, fireToast: Bool = false) {
        if favorites.contains(id) {
            favorites.remove(id)
            removeFromAllCollections(productId: id)
        } else {
            favorites.insert(id)
            if fireToast {
                pendingToast = FavoriteToast(productId: id, issuedAt: Date())
            }
        }
    }

    func isFavorite(_ id: String) -> Bool {
        favorites.contains(id)
    }

    func seedFavorites(with products: [Product]) {
        if favorites.isEmpty {
            let seed = ["p1", "p2", "p7", "p10", "p16"]
            favorites = Set(seed.filter { id in products.contains(where: { $0.id == id }) })
        }
        if collections.isEmpty {
            seedDefaultCollections()
        }
    }

    // MARK: Bookings

    func addBooking(_ b: Booking) {
        bookings.append(b)
    }

    // MARK: Collections CRUD

    func createCollection(
        name: String,
        mood: CollectionMood,
        customEmoji: String? = nil,
        customAccentHex: String? = nil,
        seedProductIds: [String] = []
    ) -> FavCollection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = trimmed.isEmpty ? mood.label : trimmed
        let c = FavCollection(
            name: final,
            mood: mood,
            productIds: seedProductIds,
            customEmoji: customEmoji,
            customAccentHex: customAccentHex
        )
        collections.insert(c, at: 0)
        return c
    }

    func renameCollection(
        id: String,
        to name: String,
        mood: CollectionMood,
        customEmoji: String? = nil,
        customAccentHex: String? = nil
    ) {
        guard let idx = collections.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        collections[idx].name = trimmed.isEmpty ? mood.label : trimmed
        collections[idx].mood = mood
        collections[idx].customEmoji = customEmoji
        collections[idx].customAccentHex = customAccentHex
    }

    func deleteCollection(id: String) {
        collections.removeAll { $0.id == id }
    }

    func addToCollection(productId: String, collectionId: String) {
        guard let idx = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        if !collections[idx].productIds.contains(productId) {
            collections[idx].productIds.append(productId)
        }
        if !favorites.contains(productId) {
            favorites.insert(productId)
        }
    }

    func removeFromCollection(productId: String, collectionId: String) {
        guard let idx = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        collections[idx].productIds.removeAll { $0 == productId }
    }

    func collection(id: String) -> FavCollection? {
        collections.first { $0.id == id }
    }

    func collections(containing productId: String) -> [FavCollection] {
        collections.filter { $0.productIds.contains(productId) }
    }

    func reorderProducts(in collectionId: String, to newOrder: [String]) {
        guard let idx = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        let existing = Set(collections[idx].productIds)
        let filtered = newOrder.filter { existing.contains($0) }
        let missing = collections[idx].productIds.filter { !filtered.contains($0) }
        collections[idx].productIds = filtered + missing
    }

    // MARK: Toast

    func dismissToast() {
        pendingToast = nil
    }

    // MARK: Recent searches

    private let recentSearchesLimit = 8

    /// Records a submitted query as the most recent search. Dedupes
    /// case-insensitively so re-typing "Totême" after "totême" just
    /// bumps the existing entry to the top instead of duplicating it.
    func recordSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return } // ignore single-char noise
        let folded = trimmed.lowercased()
        var next = recentSearches.filter { $0.lowercased() != folded }
        next.insert(trimmed, at: 0)
        if next.count > recentSearchesLimit {
            next = Array(next.prefix(recentSearchesLimit))
        }
        recentSearches = next
    }

    func clearRecentSearches() {
        recentSearches = []
    }

    // MARK: Bulk selection

    var isInBulkSelection: Bool { bulkSelection != nil }

    func enterBulkSelection(with id: String) {
        bulkSelection = [id]
    }

    /// Adds / removes an id from the current selection. A flag controls the
    /// auto-exit behavior: FavoritesView disables auto-exit on tap because
    /// tapping the originally long-pressed card would otherwise instantly
    /// close the mode the user just opened.
    func toggleBulkSelection(_ id: String, autoExitWhenEmpty: Bool = true) {
        guard var sel = bulkSelection else { return }
        if sel.contains(id) {
            sel.remove(id)
        } else {
            sel.insert(id)
        }
        if sel.isEmpty && autoExitWhenEmpty {
            bulkSelection = nil
        } else {
            bulkSelection = sel
        }
    }

    func exitBulkSelection() {
        bulkSelection = nil
    }

    // MARK: Persistence

    private func persistCollections() {
        guard let data = try? JSONEncoder().encode(collections) else { return }
        UserDefaults.standard.set(data, forKey: "collections.v1")
    }

    private func loadCollections() -> [FavCollection] {
        guard let data = UserDefaults.standard.data(forKey: "collections.v1"),
              let decoded = try? JSONDecoder().decode([FavCollection].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persistFavorites() {
        let array = Array(favorites)
        UserDefaults.standard.set(array, forKey: "favorites.v1")
    }

    private func loadFavorites() -> Set<String> {
        if let array = UserDefaults.standard.stringArray(forKey: "favorites.v1") {
            return Set(array)
        }
        return []
    }

    private func persistRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recentSearches.v1")
    }

    private func loadRecentSearches() -> [String] {
        UserDefaults.standard.stringArray(forKey: "recentSearches.v1") ?? []
    }

    private func removeFromAllCollections(productId: String) {
        for i in collections.indices {
            collections[i].productIds.removeAll { $0 == productId }
        }
    }

    private func seedDefaultCollections() {
        let spring = FavCollection(
            name: "Весна 26",
            mood: .spring,
            productIds: ["p1", "p2", "p7"].filter { favorites.contains($0) }
        )
        let office = FavCollection(
            name: "Офис",
            mood: .office,
            productIds: ["p10"].filter { favorites.contains($0) }
        )
        collections = [spring, office]
    }
}
