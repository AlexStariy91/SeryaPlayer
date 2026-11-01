import Domain
import Foundation

/// Resolves `Track.artworkKey` to a file URL and remembers the answer, so rows get their URL
/// synchronously instead of resolving it (and re-rendering) every time they scroll into view.
@MainActor
final class ArtworkResolver {
    private struct CacheKey: Hashable {
        let key: String
        let isLarge: Bool
    }

    private let store: any ArtworkStoring
    private var cache: [CacheKey: URL] = [:]

    init(store: any ArtworkStoring) {
        self.store = store
    }

    func cachedURL(for key: String?, size: Domain.ArtworkSize) -> URL? {
        guard let key else { return nil }
        return cache[CacheKey(key: key, isLarge: size == .large)]
    }

    func url(for key: String?, size: Domain.ArtworkSize) async -> URL? {
        guard let key else { return nil }
        let cacheKey = CacheKey(key: key, isLarge: size == .large)
        if let hit = cache[cacheKey] {
            return hit
        }
        let url = await store.url(for: key, size: size)
        cache[cacheKey] = url
        return url
    }

    /// Resolves the keys not cached yet, so the rows that show them render their artwork URL synchronously.
    func prefetch(_ keys: some Sequence<String>, size: Domain.ArtworkSize) async {
        for key in Set(keys) where cachedURL(for: key, size: size) == nil {
            guard !Task.isCancelled else { return }
            _ = await url(for: key, size: size)
        }
    }
}
