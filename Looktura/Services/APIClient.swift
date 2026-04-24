import Foundation

protocol APIClient {
    func fetchCatalog() async throws -> CatalogData
}

enum APIError: Error {
    case notFound
    case decodingFailed
    case network(Error)
}

final class MockAPIClient: APIClient {
    private let bundle: Bundle
    private let delayNanoseconds: UInt64

    init(bundle: Bundle = .main, simulatedDelayMs: UInt64 = 150) {
        self.bundle = bundle
        self.delayNanoseconds = simulatedDelayMs * 1_000_000
    }

    func fetchCatalog() async throws -> CatalogData {
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        guard let url = bundle.url(forResource: "mock_data", withExtension: "json") else {
            throw APIError.notFound
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CatalogData.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }
}

final class RemoteAPIClient: APIClient {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchCatalog() async throws -> CatalogData {
        let request = URLRequest(url: baseURL.appendingPathComponent("catalog"))
        do {
            let (data, _) = try await session.data(for: request)
            return try JSONDecoder().decode(CatalogData.self, from: data)
        } catch let decodingError as DecodingError {
            throw APIError.decodingFailed
        } catch {
            throw APIError.network(error)
        }
    }
}
