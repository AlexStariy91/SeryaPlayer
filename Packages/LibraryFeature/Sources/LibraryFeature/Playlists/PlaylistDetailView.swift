import DesignSystem
import Domain
import SwiftUI

struct PlaylistDetailView: View {
    let context: LibraryContext
    @State private var viewModel: PlaylistDetailViewModel
    @State private var isPickingTracks = false

    init(context: LibraryContext, playlistID: Playlist.ID, viewModel: PlaylistDetailViewModel? = nil) {
        self.context = context
        _viewModel = State(
            initialValue: viewModel ?? PlaylistDetailViewModel(playlistID: playlistID, playlists: context.playlists, store: context.store)
        )
    }

    var body: some View {
        let rows = viewModel.rows
        List {
            Section {
                header(isEmpty: rows.isEmpty)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(rows) { row in
                    LibraryTrackRow(
                        track: row.track,
                        isPlaying: context.store.nowPlayingID == row.track.id,
                        resolver: context.artwork,
                        actions: context.actions,
                        onRemove: { Task { await viewModel.remove(entryIDs: [row.id]) } },
                        onPlay: { context.startPlayback(rows.map(\.track), startingAt: rows.firstIndex(of: row) ?? 0) }
                    )
                }
                .onMove { source, destination in
                    Task { await viewModel.move(fromOffsets: source, toOffset: destination) }
                }
                .onDelete { offsets in
                    Task { await viewModel.remove(atOffsets: offsets) }
                }
            } footer: {
                if viewModel.hasLoaded, rows.isEmpty {
                    Text("This playlist is empty. Tap Add Songs to fill it.", bundle: .module)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.xl)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(context.store.playlist(id: viewModel.playlistID)?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(String(localized: "Add Songs", bundle: .module), systemImage: "plus") {
                    isPickingTracks = true
                }
                .accessibilityIdentifier("playlist.addSongs")
                EditButton()
            }
        }
        .sheet(isPresented: $isPickingTracks) {
            TrackPickerView(tracks: context.store.tracks, resolver: context.artwork) { ids in
                Task { await viewModel.append(ids) }
            }
        }
        .alert(String(localized: "Something Went Wrong", bundle: .module), isPresented: $viewModel.isShowingError) {
            Button(String(localized: "OK", bundle: .module), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.observe()
        }
    }

    private func header(isEmpty: Bool) -> some View {
        VStack(spacing: Spacing.m) {
            PlaylistCover(artworkKeys: viewModel.coverKeys, size: .grid, resolver: context.artwork)
            VStack(spacing: Spacing.xxs) {
                Text(context.store.playlist(id: viewModel.playlistID)?.name ?? "")
                    .font(AppFont.title)
                    .multilineTextAlignment(.center)
                Text(Strings.songCount(viewModel.rows.count))
                    .font(AppFont.rowSubtitle)
                    .foregroundStyle(SemanticColor.textSecondary)
            }
            PlayShuffleButtons(isEnabled: !isEmpty) {
                context.startPlayback(viewModel.tracks)
            } onShuffle: {
                context.startPlayback.shuffleAll(viewModel.tracks)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s)
    }
}
