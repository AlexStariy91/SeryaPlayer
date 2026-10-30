import DesignSystem
import Domain
import SwiftUI

/// Albums as a two-or-more-column grid that adapts to the width (landscape gets more columns).
struct AlbumsView: View {
    let context: LibraryContext

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: Spacing.l, alignment: .top)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.xl) {
                ForEach(context.store.albums) { album in
                    NavigationLink(value: LibraryRoute.group(album.id)) {
                        AlbumTile(album: album, resolver: context.artwork)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.screenMargin)
        }
        .navigationTitle(Text("Albums", bundle: .module))
        .overlay {
            if context.store.albums.isEmpty {
                ContentUnavailableView(String(localized: "No Albums", bundle: .module), systemImage: "square.stack")
            }
        }
    }
}

private struct AlbumTile: View {
    let album: TrackGroup
    let resolver: ArtworkResolver

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ResolvedArtwork(key: album.artworkKey, size: .grid, resolver: resolver)
            Text(Strings.album(album.name))
                .font(AppFont.rowTitle)
                .foregroundStyle(SemanticColor.textPrimary)
                .lineLimit(1)
            Text(Strings.artist(album.artist))
                .font(AppFont.rowSubtitle)
                .foregroundStyle(SemanticColor.textSecondary)
                .lineLimit(1)
        }
        .frame(width: DesignSystem.ArtworkSize.grid.points, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
