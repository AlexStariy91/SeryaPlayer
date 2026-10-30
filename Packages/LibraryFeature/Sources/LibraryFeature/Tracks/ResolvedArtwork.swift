import DesignSystem
import Domain
import SwiftUI

/// `ArtworkView` for an artwork key: resolves the URL through `ArtworkResolver`, synchronously when cached.
struct ResolvedArtwork: View {
    let key: String?
    let size: DesignSystem.ArtworkSize
    let resolver: ArtworkResolver

    @State private var url: URL?

    var body: some View {
        ArtworkView(url: url ?? resolver.cachedURL(for: key, size: storeSize), size: size)
            .task(id: key) {
                url = await resolver.url(for: key, size: storeSize)
            }
    }

    private var storeSize: Domain.ArtworkSize {
        size.points > 120 ? .large : .thumbnail
    }
}
