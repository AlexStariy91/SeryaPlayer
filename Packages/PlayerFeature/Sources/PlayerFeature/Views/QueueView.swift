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
                        QueueRow(track: item.track, isPlaying: viewModel.snapshot.isPlaying, resolveArtwork: viewModel.thumbnailURL)
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
            QueueRow(track: item.track, isPlaying: false, resolveArtwork: viewModel.thumbnailURL)
        }
        .buttonStyle(.plain)
    }
}

private struct QueueRow: View {
    let track: Track
    let isPlaying: Bool
    let resolveArtwork: (Track) async -> URL?

    @State private var artworkURL: URL?

    var body: some View {
        TrackRow(title: track.title, subtitle: track.artist, artworkURL: artworkURL, duration: track.duration, isPlaying: isPlaying)
            .task(id: track.artworkKey) { artworkURL = await resolveArtwork(track) }
    }
}

#Preview("Queue") {
    let preview = PreviewPlayer.playing()
    QueueView(viewModel: preview.viewModel)
        .task { await preview.viewModel.observe() }
}
