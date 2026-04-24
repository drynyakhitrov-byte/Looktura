import SwiftUI

@main
struct LookturaApp: App {
    init() {
        AppFont.registerFonts()
        // Touch the cache early so URLCache is configured before anything
        // kicks off its first network request.
        _ = ImageCache.shared
    }

    @State private var appState = AppState()
    @State private var repository = DataRepository()
    @State private var mapAvailability = MapAvailability()

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState, repository: repository, mapAvailability: mapAvailability)
                .environment(\.appTheme, appState.theme)
                .preferredColorScheme(appState.theme.isDark ? .dark : .light)
                .tint(appState.theme.ink)
                .task {
                    await repository.load()
                    appState.seedFavorites(with: repository.products)
                    // Warm decoded bitmaps for the top of the swipe stack
                    // and store covers so the first cards render instantly.
                    let productURLs = repository.products.prefix(14).compactMap(\.imageURL)
                    let storeURLs = repository.stores.prefix(8).compactMap(\.coverURL)
                    ImageCache.shared.prefetch(productURLs + storeURLs)
                }
                .task {
                    await mapAvailability.refreshIfNeeded()
                }
        }
    }
}
