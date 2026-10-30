import DesignSystem
import Domain
import SwiftUI

/// An artist's or an album's tracks with Play and Shuffle.
struct TrackGroupView: View {
    let context: LibraryContext
    let groupID: String

    var body: some View {
        if let group = context.store.group(id: groupID) {
            List {
                Section {
                    header(group)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(group.tracks) { track in
                        LibraryTrackRow(
                            track: track,
                            isPlaying: context.store.nowPlayingID == track.id,
                            resolver: context.artwork,
                            actions: context.actions
                        ) {
                            context.startPlayback(group.tracks, startingAt: group.tracks.firstIndex(of: track) ?? 0)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(group.kind == .artist ? Strings.artist(group.name) : Strings.album(group.name))
            .navigationBarTitleDisplayMode(.inline)
        } else {
            // The last track of this artist/album was deleted while the screen was open.
            ContentUnavailableView(String(localized: "No Songs", bundle: .module), systemImage: "music.note")
        }
    }

    private func header(_ group: TrackGroup) -> some View {
        VStack(spacing: Spacing.m) {
            ResolvedArtwork(key: group.artworkKey, size: .grid, resolver: context.artwork)
            VStack(spacing: Spacing.xxs) {
                Text(group.kind == .artist ? Strings.artist(group.name) : Strings.album(group.name))
                    .font(AppFont.title)
                    .multilineTextAlignment(.center)
                Text(subtitle(group))
                    .font(AppFont.rowSubtitle)
                    .foregroundStyle(SemanticColor.textSecondary)
            }
            PlayShuffleButtons(isEnabled: !group.tracks.isEmpty) {
                context.startPlayback(group.tracks)
            } onShuffle: {
                context.startPlayback.shuffleAll(group.tracks)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s)
    }

    private func subtitle(_ group: TrackGroup) -> String {
        switch group.kind {
        case .artist:
            String(localized: "\(group.albumCount) albums · \(group.tracks.count) songs", bundle: .module)
        case .album:
            Strings.artist(group.artist) + " · " + Strings.songCount(group.tracks.count)
        }
    }
}
