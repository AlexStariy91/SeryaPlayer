import DesignSystem
import Domain
import SwiftUI

/// A horizontal "Recently Added" / "Recently Played" shelf. Tapping plays the shelf from that track.
struct TrackShelf: View {
    let tracks: [Track]
    let context: LibraryContext

    private static let artwork = DesignSystem.ArtworkSize.custom(140)

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: Spacing.m) {
                ForEach(tracks) { track in
                    Button {
                        context.startPlayback(tracks, startingAt: tracks.firstIndex(of: track) ?? 0)
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ResolvedArtwork(key: track.artworkKey, size: Self.artwork, resolver: context.artwork)
                            Text(track.title)
                                .font(AppFont.rowSubtitle)
                                .foregroundStyle(SemanticColor.textPrimary)
                                .lineLimit(1)
                            Text(Strings.artist(track.artist))
                                .font(AppFont.caption)
                                .foregroundStyle(SemanticColor.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(width: Self.artwork.points, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        TrackActionButtons(track: track, actions: context.actions)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Spacing.screenMargin)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }
}
