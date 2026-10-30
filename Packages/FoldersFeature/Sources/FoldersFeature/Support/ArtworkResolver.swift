import Domain
import Foundation

/// Resolves `Track.artworkKey` to a file URL and remembers the answer, so rows that scroll back
/// into view get their URL synchronously instead of flashing the placeholder.
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
}
