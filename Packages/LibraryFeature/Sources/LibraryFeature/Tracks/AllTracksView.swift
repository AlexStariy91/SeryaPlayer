import DesignSystem
import Domain
import SwiftUI

struct AllTracksView: View {
    let context: LibraryContext
    @State private var viewModel: AllTracksViewModel

    init(context: LibraryContext, viewModel: AllTracksViewModel? = nil) {
        self.context = context
        _viewModel = State(initialValue: viewModel ?? AllTracksViewModel(tracks: context.tracks, settings: context.settings))
    }

    var body: some View {
        List {
            ForEach(viewModel.visibleTracks) { track in
                LibraryTrackRow(
                    track: track,
                    isPlaying: context.store.nowPlayingID == track.id,
                    resolver: context.artwork,
                    actions: context.actions
                ) {
                    let list = viewModel.visibleTracks
                    context.startPlayback(list, startingAt: list.firstIndex(of: track) ?? 0)
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.isSearching, viewModel.results?.isEmpty == true {
                ContentUnavailableView.search(text: viewModel.query)
            } else if viewModel.hasLoaded, viewModel.tracks.isEmpty {
                EmptyStateView(
                    LocalizedStringKey(String(localized: "No Songs", bundle: .module)),
                    systemImage: "music.note",
                    message: LocalizedStringKey(String(localized: "Import audio files to see them here.", bundle: .module)),
                    actionTitle: LocalizedStringKey(String(localized: "Import Files", bundle: .module))
                ) {
                    context.importer.present(.files)
                }
            }
        }
        .navigationTitle(Text("All Tracks", bundle: .module))
        .searchable(text: $viewModel.query, prompt: Text("Songs, artists, albums", bundle: .module))
        .searchScopes($viewModel.scope) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Text(Strings.scope(scope)).tag(scope)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                sortMenu
            }
        }
        .task(id: viewModel.sort) {
            await viewModel.observe()
        }
        .task(id: SearchKey(query: viewModel.query, scope: viewModel.scope)) {
            // Debounce: a newer keystroke cancels this task before it searches.
            if viewModel.isSearching {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
            }
            await viewModel.search()
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(TrackSort.Field.allCases, id: \.self) { field in
                Button {
                    viewModel.setSort(field)
                } label: {
                    if viewModel.sort.field == field {
                        Label(Strings.sortField(field), systemImage: viewModel.sort.ascending ? "chevron.up" : "chevron.down")
                    } else {
                        Text(Strings.sortField(field))
                    }
                }
            }
        } label: {
            Label(String(localized: "Sort", bundle: .module), systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("library.sort")
    }
}

private struct SearchKey: Hashable {
    let query: String
    let scope: SearchScope
}
