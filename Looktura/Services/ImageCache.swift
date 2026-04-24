import SwiftUI
import UIKit

/// Thread-safe wrapper around NSCache. NSCache is already safe for concurrent
/// access — this wrapper only exists to declare that fact to the Swift
/// concurrency checker (`@unchecked Sendable`).
private final class MemoryStore: @unchecked Sendable {
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 240
        cache.totalCostLimit = 140 * 1024 * 1024 // ~140 MB decoded budget
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL, cost: Int) {
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

/// Shared image cache with an in-memory NSCache layer plus URLCache on disk.
/// Decodes on a background queue so SwiftUI hands back a ready bitmap —
/// eliminates the per-frame decoding stall that `AsyncImage` suffers from
/// when many product cards appear at once.
///
/// Isolated as an `actor` so the `inFlight` dictionary is never mutated
/// concurrently from multiple prefetch tasks (a race that corrupts the
/// dictionary and crashes with a bogus NSIndexPath selector forwarding).
actor ImageCache {
    static let shared = ImageCache()

    nonisolated private let store = MemoryStore()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        let mem = 40 * 1024 * 1024
        let disk = 300 * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: mem, diskCapacity: disk, directory: nil)
    }

    /// Synchronous memory-cache probe. Nil if the URL hasn't been decoded yet.
    /// `nonisolated` because NSCache is already thread-safe — no actor hop needed.
    nonisolated func cached(for url: URL) -> UIImage? {
        store.image(for: url)
    }

    /// Fetches and caches. Coalesces concurrent requests for the same URL.
    @discardableResult
    func load(_ url: URL) async -> UIImage? {
        if let hit = store.image(for: url) {
            return hit
        }
        if let running = inFlight[url] {
            return await running.value
        }

        let memStore = store
        let task = Task<UIImage?, Never> {
            var req = URLRequest(url: url)
            req.cachePolicy = .returnCacheDataElseLoad
            req.timeoutInterval = 20

            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                guard let raw = UIImage(data: data) else { return nil }
                let decoded = raw.preparingForDisplay() ?? raw
                memStore.store(decoded, for: url, cost: data.count)
                return decoded
            } catch {
                return nil
            }
        }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        return result
    }

    /// Fire-and-forget warmup for a batch of URLs.
    /// `nonisolated` so callers (e.g. app startup) don't need to await an actor
    /// hop just to kick off background warm-ups.
    nonisolated func prefetch(_ urls: [URL?]) {
        let real = urls.compactMap { $0 }
        for url in real where store.image(for: url) == nil {
            Task.detached(priority: .utility) {
                _ = await ImageCache.shared.load(url)
            }
        }
    }
}

/// Drop-in replacement for `AsyncImage` that funnels through `ImageCache`.
/// Shows `placeholder` while loading, cross-fades to the decoded image.
struct CachedImage<Placeholder: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let ui = image {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            // Synchronous hit path: no flicker, no async dispatch, no flash of placeholder.
            if let hit = ImageCache.shared.cached(for: url) {
                image = hit
                return
            }
            let loaded = await ImageCache.shared.load(url)
            guard !Task.isCancelled else { return }
            if image == nil {
                withAnimation(.easeOut(duration: 0.22)) {
                    image = loaded
                }
            } else {
                image = loaded
            }
        }
    }
}
