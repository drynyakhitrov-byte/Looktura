import Foundation
import Observation

@Observable
final class DataRepository {
    enum LoadState { case idle, loading, loaded, failed }

    private(set) var stores: [Store] = []
    private(set) var products: [Product] = []
    private(set) var notifications: [AppNotification] = []
    private(set) var loadState: LoadState = .idle

    private let client: APIClient

    init(client: APIClient = MockAPIClient()) {
        self.client = client
    }

    func load() async {
        loadState = .loading
        do {
            let data = try await client.fetchCatalog()
            self.stores = data.stores
            self.products = data.products
            self.notifications = data.notifications
            self.loadState = .loaded
        } catch {
            self.loadState = .failed
        }
    }

    func store(id: String) -> Store? {
        stores.first { $0.id == id }
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }

    func products(inStore storeId: String) -> [Product] {
        products.filter { $0.storeId == storeId }
    }
}
