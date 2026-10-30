import DesignSystem
import Domain
import SwiftUI

struct PlaylistsView: View {
    let context: LibraryContext
    @State private var viewModel: PlaylistsViewModel
    @State private var naming: NamingTarget?
    @State private var name = ""

    init(context: LibraryContext) {
        self.context = context
        _viewModel = State(initialValue: PlaylistsViewModel(playlists: context.playlists))
    }

    var body: some View {
        List {
            Button(String(localized: "New Playlist…", bundle: .module), systemImage: "plus") {
                startNaming(.new)
            }
            .accessibilityIdentifier("playlists.new")
            ForEach(context.store.playlists) { playlist in
                NavigationLink(value: LibraryRoute.playlist(playlist.id)) {
                    PlaylistRow(playlist: playlist, context: context)
                }
                .contextMenu {
                    Button(String(localized: "Rename…", bundle: .module), systemImage: "pencil") {
                        startNaming(.rename(playlist))
                    }
                    Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) {
                        Task { await viewModel.delete(playlist) }
                    }
                }
                .swipeActions {
                    Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) {
                        Task { await viewModel.delete(playlist) }
                    }
                    Button(String(localized: "Rename…", bundle: .module), systemImage: "pencil") {
                        startNaming(.rename(playlist))
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(Text("Playlists", bundle: .module))
        .alert(naming?.title ?? "", isPresented: isNaming) {
            TextField(String(localized: "Name", bundle: .module), text: $name)
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            Button(naming?.confirmTitle ?? "") { commitName() }
        }
        .alert(String(localized: "Something Went Wrong", bundle: .module), isPresented: $viewModel.isShowingError) {
            Button(String(localized: "OK", bundle: .module), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var isNaming: Binding<Bool> {
        Binding { naming != nil } set: {
            if !$0 {
                naming = nil
            }
        }
    }

    private func startNaming(_ target: NamingTarget) {
        if case let .rename(playlist) = target {
            name = playlist.name
        } else {
            name = ""
        }
        naming = target
    }

    private func commitName() {
        guard let target = naming else { return }
        let name = name
        Task {
            switch target {
            case .new: await viewModel.create(named: name)
            case let .rename(playlist): await viewModel.rename(playlist, to: name)
            }
        }
    }
}

private enum NamingTarget {
    case new
    case rename(Playlist)

    var title: String {
        switch self {
        case .new: String(localized: "New Playlist", bundle: .module)
        case .rename: String(localized: "Rename Playlist", bundle: .module)
        }
    }

    var confirmTitle: String {
        switch self {
        case .new: String(localized: "Create", bundle: .module)
        case .rename: String(localized: "Rename", bundle: .module)
        }
    }
}

/// A playlist row with its live collage cover and song count.
struct PlaylistRow: View {
    let playlist: Playlist
    let context: LibraryContext

    @State private var entries: [PlaylistEntry] = []

    var body: some View {
        HStack(spacing: Spacing.m) {
            PlaylistCover(
                artworkKeys: PlaylistCover.keys(for: entries, tracksByID: context.store.tracksByID),
                size: .custom(56),
                resolver: context.artwork
            )
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(playlist.name)
                    .font(AppFont.rowTitle)
                    .lineLimit(1)
                Text(Strings.songCount(entries.count))
                    .font(AppFont.rowSubtitle)
                    .foregroundStyle(SemanticColor.textSecondary)
            }
        }
        .task(id: playlist.id) {
            for await list in context.playlists.observeEntries(of: playlist.id) {
                entries = list.sorted { $0.sortIndex < $1.sortIndex }
            }
        }
    }
}
