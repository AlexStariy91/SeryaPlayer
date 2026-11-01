import DesignSystem
import Domain
import SwiftUI

/// A tappable `TrackRow` with resolved artwork and the shared track actions.
struct LibraryTrackRow: View {
    let track: Track
    let nowPlaying: TrackRow.NowPlaying?
    let resolver: ArtworkResolver
    let actions: TrackActionsModel
    /// In a playlist: the trailing swipe removes the entry instead of deleting the track.
    var onRemove: (() -> Void)?
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            ResolvingArtworkURL(key: track.artworkKey, size: .thumbnail, resolver: resolver) { url in
                TrackRow(
                    title: track.title,
                    subtitle: Strings.subtitle(for: track),
                    artworkURL: url,
                    duration: track.duration,
                    nowPlaying: nowPlaying
                )
            }
        }
        .buttonStyle(.plain)
        .trackActions(for: track, actions: actions, onRemove: onRemove)
    }
}
