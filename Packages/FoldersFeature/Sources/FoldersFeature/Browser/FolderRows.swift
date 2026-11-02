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

/// A tappable `TrackRow`. The artwork URL usually comes from the resolver's cache (the store prefetches it).
struct FolderTrackRow: View {
    let track: Track
    /// Read in this body, not the list's: only visible rows depend on the playing track.
    let playback: FoldersStore
    let resolver: ArtworkResolver
    /// While editing, taps go to the list's selection instead of playing.
    var isEditing = false
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            ResolvingArtworkURL(key: track.artworkKey, resolver: resolver) { url in
                TrackRow(
                    title: track.title,
                    subtitle: [track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · "),
                    artworkURL: url,
                    duration: track.duration,
                    nowPlaying: playback.nowPlaying(track.id),
                    levels: playback.rowLevels
                )
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isEditing)
    }
}

/// Hands `content` the thumbnail URL for `key`: synchronously from the resolver's cache, or after resolving a
/// miss in a task. Rows that scroll back into view then render once instead of placeholder → artwork.
struct ResolvingArtworkURL<Content: View>: View {
    let key: String?
    let resolver: ArtworkResolver
    @ViewBuilder let content: (URL?) -> Content

    /// The URL resolved for a key, kept with the key so a reused row never shows another track's artwork.
    @State private var resolved: (key: String, url: URL?)?

    var body: some View {
        let cached = resolver.cachedURL(for: key, size: .thumbnail)
        content(cached ?? resolved.flatMap { $0.key == key ? $0.url : nil })
            .background {
                if cached == nil, let key {
                    Color.clear.task(id: key) {
                        resolved = await (key, resolver.url(for: key, size: .thumbnail))
                    }
                }
            }
    }
}
