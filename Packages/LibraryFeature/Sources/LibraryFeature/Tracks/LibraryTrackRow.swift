import DesignSystem
import Domain
import SwiftUI

/// A tappable `TrackRow` with asynchronously resolved artwork and the shared track actions.
struct LibraryTrackRow: View {
    let track: Track
    let isPlaying: Bool
    let resolver: ArtworkResolver
    let actions: TrackActionsModel
    /// In a playlist: the trailing swipe removes the entry instead of deleting the track.
    var onRemove: (() -> Void)?
    let onPlay: () -> Void

    @State private var artworkURL: URL?

    var body: some View {
        Button(action: onPlay) {
            TrackRow(
                title: track.title,
                subtitle: Strings.subtitle(for: track),
                artworkURL: artworkURL ?? resolver.cachedURL(for: track.artworkKey, size: .thumbnail),
                duration: track.duration,
                isPlaying: isPlaying
            )
        }
        .buttonStyle(.plain)
        .task(id: track.artworkKey) {
            artworkURL = await resolver.url(for: track.artworkKey, size: .thumbnail)
        }
        .trackActions(for: track, actions: actions, onRemove: onRemove)
    }
}
