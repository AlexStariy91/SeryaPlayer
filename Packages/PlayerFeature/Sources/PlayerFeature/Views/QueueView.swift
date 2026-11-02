import DesignSystem
import Domain
import SwiftUI

/// The queue: the current track and what plays next. Drag to reorder, swipe to remove, tap to play.
struct QueueView: View {
    let viewModel: PlayerViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let item = viewModel.nowPlayingItem {
                    Section {
                        QueueRow(track: item.track, nowPlaying: viewModel.snapshot.isPlaying ? .playing : .paused, viewModel: viewModel)
                    } header: {
                        Text("Now Playing", bundle: .module)
                    }
                }
                Section {
                    if viewModel.upNext.isEmpty {
                        Text("Nothing Up Next", bundle: .module)
                            .foregroundStyle(SemanticColor.textSecondary)
                    } else {
                        ForEach(viewModel.upNext) { item in
                            row(item)
                        }
                        .onMove(perform: viewModel.moveUpNext)
                        .onDelete(perform: viewModel.removeUpNext)
                    }
                } header: {
                    Text("Up Next", bundle: .module)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("Queue", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done", bundle: .module)
                    }
                }
            }
        }
    }

    private func row(_ item: QueueItem) -> some View {
        Button {
            viewModel.play(item)
        } label: {
            QueueRow(track: item.track, nowPlaying: nil, viewModel: viewModel)
        }
        .buttonStyle(.plain)
    }
}

private struct QueueRow: View {
    let track: Track
    let nowPlaying: TrackRow.NowPlaying?
    let viewModel: PlayerViewModel

    /// Resolved on a cache miss, kept with the key so a reused row never shows another track's artwork.
    @State private var resolved: (key: String, url: URL?)?

    var body: some View {
        let cached = viewModel.cachedThumbnailURL(for: track)
        TrackRow(
            title: track.title,
            subtitle: track.artist,
            artworkURL: cached ?? resolved.flatMap { $0.key == track.artworkKey ? $0.url : nil },
            duration: track.duration,
            nowPlaying: nowPlaying,
            levels: { viewModel.spectrum.spectrum() }
        )
        .background {
            if cached == nil, let key = track.artworkKey {
                Color.clear.task(id: key) {
                    resolved = await (key, viewModel.thumbnailURL(for: track))
                }
            }
        }
    }
}

#if DEBUG
    #Preview("Queue") {
        let preview = PreviewPlayer.playing()
        QueueView(viewModel: preview.viewModel)
            .task { await preview.viewModel.observe() }
    }
#endif
