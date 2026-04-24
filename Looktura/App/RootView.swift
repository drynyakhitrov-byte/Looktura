import SwiftUI

struct RootView: View {
    @Bindable var appState: AppState
    @Bindable var repository: DataRepository
    @Bindable var mapAvailability: MapAvailability

    var body: some View {
        ZStack {
            if !appState.hasCompletedOnboarding {
                OnboardingFlow(appState: appState)
                    .transition(.opacity)
            } else {
                MainTabView(appState: appState, repository: repository, mapAvailability: mapAvailability)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.hasCompletedOnboarding)
    }
}

struct MainTabView: View {
    @Bindable var appState: AppState
    @Bindable var repository: DataRepository
    @Bindable var mapAvailability: MapAvailability

    @State private var path: [Route] = []
    @State private var modalRoute: Route? = nil
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent

            if path.isEmpty {
                BottomBar(
                    appState: appState,
                    onPickCollection: { ids in modalRoute = .pickCollection(productIds: ids) }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let toast = appState.pendingToast, modalRoute == nil {
                FavoriteToastView(
                    product: repository.product(id: toast.productId),
                    onPickCollection: {
                        let pid = toast.productId
                        appState.dismissToast()
                        modalRoute = .pickCollection(productIds: [pid])
                    },
                    onDismiss: {
                        appState.dismissToast()
                    }
                )
                .id(toast.issuedAt)
                .padding(.bottom, path.isEmpty ? 96 : 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .sheet(item: modalBinding) { route in
            modalDestination(for: route)
                .environment(\.appTheme, theme)
                .preferredColorScheme(theme.isDark ? .dark : .light)
        }
        .animation(.easeOut(duration: 0.2), value: appState.selectedTab)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: appState.pendingToast)
        .animation(.spring(response: 0.45, dampingFraction: 0.88), value: path.isEmpty)
    }

    private var modalBinding: Binding<Route?> {
        Binding(
            get: { modalRoute },
            set: { modalRoute = $0 }
        )
    }

    @ViewBuilder
    private var tabContent: some View {
        NavigationStack(path: $path) {
            currentTabView
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch appState.selectedTab {
        case .feed:
            SwipeFeedView(
                appState: appState,
                repository: repository,
                onOpenDetail: { pushDetail($0) },
                onOpenSearch: { modalRoute = .search }
            )
        case .catalog:
            CatalogView(
                appState: appState,
                repository: repository,
                onOpenProduct: { pushDetail($0) }
            )
        case .map:
            MapView(
                repository: repository,
                mapAvailability: mapAvailability,
                hasFavoriteStores: !favoriteStoreIds().isEmpty,
                onOpenStore: { pushStore($0) },
                onOpenRoute: { pushRoute(collectionId: nil) }
            )
        case .favorites:
            FavoritesView(
                appState: appState,
                repository: repository,
                onOpenProduct: { pushDetail($0) },
                onGoToFeed: { appState.selectedTab = .feed },
                onOpenCollection: { pushCollectionDetail($0) },
                onOpenRoute: { pushRoute(collectionId: $0) },
                onCreateNewCollection: { modalRoute = .newCollection(seedProductIds: []) }
            )
        case .profile:
            ProfileView(
                appState: appState,
                repository: repository,
                onOpenNotifications: { modalRoute = .notifications }
            )
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .detail(let id):
            DetailView(
                appState: appState,
                repository: repository,
                productId: id,
                onBack: { popLast() },
                onOpenStore: { pushStore($0) },
                onOpenRelated: { pushDetail($0) },
                onBook: { pushBooking($0) }
            )
        case .store(let id):
            StoreView(
                repository: repository,
                storeId: id,
                onBack: { popLast() },
                onOpenProduct: { pushDetail($0) }
            )
        case .booking(let id):
            BookingView(
                appState: appState,
                repository: repository,
                productId: id,
                onBack: { popLast() },
                onConfirmed: { b in
                    path.append(.bookingConfirmed(productId: b.productId, size: b.size, date: b.date, time: b.time))
                }
            )
        case .bookingConfirmed(let pid, let size, let date, let time):
            if let p = repository.product(id: pid) {
                let booking = Booking(id: UUID(), productId: pid, storeId: p.storeId, size: size, date: date, time: time)
                BookingConfirmedView(
                    repository: repository,
                    booking: booking,
                    onHome: {
                        path.removeAll()
                        appState.selectedTab = .feed
                    },
                    onMyBookings: {
                        path.removeAll()
                        appState.selectedTab = .profile
                    }
                )
            }
        case .collectionDetail(let id):
            CollectionDetailView(
                appState: appState,
                repository: repository,
                collectionId: id,
                onBack: { popLast() },
                onOpenProduct: { pushDetail($0) },
                onOpenRoute: { pushRoute(collectionId: $0) }
            )
        case .routeBuilder(let cid):
            RouteBuilderView(
                appState: appState,
                repository: repository,
                mapAvailability: mapAvailability,
                collectionId: cid,
                onBack: { popLast() },
                onOpenStore: { pushStore($0) }
            )
        case .search, .notifications, .pickCollection, .newCollection:
            EmptyView()
        }
    }

    @ViewBuilder
    private func modalDestination(for route: Route) -> some View {
        switch route {
        case .search:
            SearchView(
                appState: appState,
                repository: repository,
                onBack: { modalRoute = nil },
                onOpenProduct: { id in
                    modalRoute = nil
                    pushDetail(id)
                },
                onOpenStore: { id in
                    modalRoute = nil
                    pushStore(id)
                }
            )
        case .notifications:
            NotificationsView(
                repository: repository,
                onBack: { modalRoute = nil },
                onOpenProduct: { id in
                    modalRoute = nil
                    pushDetail(id)
                },
                onOpenStore: { id in
                    modalRoute = nil
                    pushStore(id)
                }
            )
        case .pickCollection(let pids):
            CollectionPickerSheet(
                appState: appState,
                repository: repository,
                productIds: pids,
                onCreateNew: {
                    // Forward the full selection so bulk-selected items all
                    // land in the freshly-created collection.
                    modalRoute = .newCollection(seedProductIds: pids)
                },
                onClose: { modalRoute = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            // Thin material lets the Favorites content behind the sheet blur
            // through, giving the rows' liquid-glass surfaces something real
            // to refract. With the system's default opaque chrome you'd see a
            // flat dark card; with .thinMaterial the sheet itself is glass.
            .presentationBackground(.thinMaterial)
        case .newCollection(let seeds):
            NewCollectionSheet(
                appState: appState,
                repository: repository,
                seedProductIds: seeds,
                onCreated: { _ in
                    modalRoute = nil
                },
                onClose: { modalRoute = nil }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.thinMaterial)
        default:
            EmptyView()
        }
    }

    private func favoriteStoreIds() -> Set<String> {
        let products = repository.products.filter { appState.isFavorite($0.id) }
        return Set(products.map(\.storeId))
    }

    private func pushDetail(_ id: String) {
        path.append(.detail(productId: id))
    }

    private func pushStore(_ id: String) {
        path.append(.store(storeId: id))
    }

    private func pushBooking(_ id: String) {
        path.append(.booking(productId: id))
    }

    private func pushCollectionDetail(_ id: String) {
        path.append(.collectionDetail(collectionId: id))
    }

    private func pushRoute(collectionId: String?) {
        path.append(.routeBuilder(collectionId: collectionId))
    }

    private func popLast() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

extension Route: Identifiable {
    var id: String {
        switch self {
        case .detail(let id): return "detail-\(id)"
        case .store(let id): return "store-\(id)"
        case .booking(let id): return "booking-\(id)"
        case .bookingConfirmed(let id, let size, _, let time): return "bc-\(id)-\(size)-\(time)"
        case .collectionDetail(let id): return "col-\(id)"
        case .routeBuilder(let cid): return "route-\(cid ?? "all")"
        case .pickCollection(let pids): return "pick-\(pids.joined(separator: ","))"
        case .newCollection(let seeds): return "new-\(seeds.isEmpty ? "blank" : seeds.joined(separator: ","))"
        case .search: return "search"
        case .notifications: return "notifications"
        }
    }
}
