import DesignSystem
import Domain
import SwiftUI

/// `ArtworkView` for an artwork key. The URL comes from the resolver's cache when it is there; only a miss
/// resolves it in a task, so views that scroll back into view render once instead of twice.
struct ResolvedArtwork: View {
    let key: String?
    let size: DesignSystem.ArtworkSize
    let resolver: ArtworkResolver

    var body: some View {
        ResolvingArtworkURL(key: key, size: storeSize, resolver: resolver) { url in
            ArtworkView(url: url, size: size)
        }
    }

    private var storeSize: Domain.ArtworkSize {
        size.points > 120 ? .large : .thumbnail
    }
}

/// Hands `content` the artwork URL for `key`: synchronously from the resolver's cache, or after resolving a miss.
struct ResolvingArtworkURL<Content: View>: View {
    let key: String?
    let size: Domain.ArtworkSize
    let resolver: ArtworkResolver
    @ViewBuilder let content: (URL?) -> Content

    /// The URL resolved for a key, kept with the key so a reused view never shows another key's artwork.
    @State private var resolved: (key: String, url: URL?)?

    var body: some View {
        let cached = resolver.cachedURL(for: key, size: size)
        content(cached ?? resolved.flatMap { $0.key == key ? $0.url : nil })
            .background {
                if cached == nil, let key {
                    Color.clear.task(id: key) {
                        resolved = await (key, resolver.url(for: key, size: size))
                    }
                }
            }
    }
}
