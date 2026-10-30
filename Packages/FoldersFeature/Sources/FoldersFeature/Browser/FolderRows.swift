import DesignSystem
import Domain
import SwiftUI

/// A folder in the list: icon, name and the number of songs below it (subfolders included).
struct FolderRow: View {
    let folder: Folder
    let songCount: Int

    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: DesignSystem.ArtworkSize.row.points, height: DesignSystem.ArtworkSize.row.points)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(folder.name)
                    .font(AppFont.rowTitle)
                    .foregroundStyle(SemanticColor.textPrimary)
                    .lineLimit(2)
                Text(songCount == 0 ? String(localized: "Empty", bundle: .module) : Strings.songCount(songCount))
                    .font(AppFont.rowSubtitle)
                    .foregroundStyle(SemanticColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A tappable `TrackRow` with asynchronously resolved artwork.
struct FolderTrackRow: View {
    let track: Track
    let isPlaying: Bool
    let resolver: ArtworkResolver
    let onPlay: () -> Void

    @State private var artworkURL: URL?

    var body: some View {
        Button(action: onPlay) {
            TrackRow(
                title: track.title,
                subtitle: [track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · "),
                artworkURL: artworkURL ?? resolver.cachedURL(for: track.artworkKey, size: .thumbnail),
                duration: track.duration,
                isPlaying: isPlaying
            )
        }
        .buttonStyle(.plain)
        .task(id: track.artworkKey) {
            artworkURL = await resolver.url(for: track.artworkKey, size: .thumbnail)
        }
    }
}

/// The Play / Shuffle pair at the top of a folder.
struct PlayShuffleButtons: View {
    let isEnabled: Bool
    let onPlay: () -> Void
    let onShuffle: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            Button(action: onPlay) {
                Label(String(localized: "Play", bundle: .module), systemImage: "play.fill")
                    // Without it the symbol takes the tint on iOS 18 and vanishes into the prominent fill.
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .adaptiveButtonStyle(prominent: true)
            .accessibilityIdentifier("folder.play")
            Button(action: onShuffle) {
                Label(String(localized: "Shuffle", bundle: .module), systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .adaptiveButtonStyle()
            .accessibilityIdentifier("folder.shuffle")
        }
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}
