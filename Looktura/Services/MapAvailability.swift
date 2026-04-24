import Foundation
import Observation

@Observable
final class MapAvailability {
    enum State {
        case checking
        case online
        case offline
    }

    var state: State = .checking
    private var didCheck = false

    func refreshIfNeeded() async {
        guard !didCheck else { return }
        didCheck = true
        await refresh()
    }

    func refresh() async {
        state = .checking
        guard let url = URL(string: "https://gspe35-ssl.ls.apple.com/geo_manifest/dynamic/config?application=geod") else {
            state = .offline
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 3.0
        req.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<600).contains(http.statusCode) {
                state = .online
            } else {
                state = .offline
            }
        } catch {
            state = .offline
        }
    }
}
