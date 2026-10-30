import DesignSystem
import Domain
import SwiftUI

struct ArtistsView: View {
    let context: LibraryContext

    var body: some View {
        List(context.store.artists) { artist in
            NavigationLink(value: LibraryRoute.group(artist.id)) {
                HStack(spacing: Spacing.m) {
                    ResolvedArtwork(key: artist.artworkKey, size: .row, resolver: context.artwork)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(Strings.artist(artist.name))
                            .font(AppFont.rowTitle)
                            .lineLimit(1)
                        Text(Strings.songCount(artist.tracks.count))
                            .font(AppFont.rowSubtitle)
                            .foregroundStyle(SemanticColor.textSecondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(Text("Artists", bundle: .module))
        .overlay {
            if context.store.artists.isEmpty {
                ContentUnavailableView(String(localized: "No Artists", bundle: .module), systemImage: "music.mic")
            }
        }
    }
}
