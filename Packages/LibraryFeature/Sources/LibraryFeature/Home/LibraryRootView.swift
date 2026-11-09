import DesignSystem
import Domain
import SwiftUI

/// The Library tab root: navigation, import, track action sheets and the live store.
struct LibraryRootView: View {
    /// Held in `@State` so a parent re-render (e.g. switching tabs) doesn't rebuild the store.
    @State private var context: LibraryContext

    @State private var path: [LibraryRoute] = []

    init(context: LibraryContext) {
        _context = State(wrappedValue: context)
    }

    var body: some View {
        @Bindable var importer = context.importer
        NavigationStack(path: $path) {
            LibraryHomeView(context: context)
                .navigationTitle(Text("Library", bundle: .module))
                .toolbar { toolbar }
                .navigationDestination(for: LibraryRoute.self, destination: destination)
        }
        .fileImporter(
            isPresented: $importer.isPickerPresented,
            allowedContentTypes: importer.source.contentTypes,
            allowsMultipleSelection: importer.source.allowsMultipleSelection,
            onCompletion: importer.handlePickerResult
        )
        .alert(
            String(localized: "Import Complete", bundle: .module),
            isPresented: $importer.isShowingSummary,
            presenting: importer.summary
        ) { _ in
            Button(String(localized: "OK", bundle: .module), role: .cancel) {}
        } message: { summary in
            Text(summary.message)
        }
        .trackActionsPresenter(context)
        .task {
            await context.store.observe()
        }
        .task {
            await importer.observeActivity()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            // One slot: the ring replaces "+" while an import runs (only one import runs at a time), and the
            // observed flag changes on start and end only, never per tick.
            if context.importer.isImporting {
                ImportProgressIndicator(importer: context.importer)
            } else {
                Menu {
                    Button(String(localized: "Files…", bundle: .module), systemImage: "doc") {
                        context.importer.present(.files)
                    }
                    Button(String(localized: "Folder…", bundle: .module), systemImage: "folder") {
                        context.importer.present(.folder)
                    }
                } label: {
                    Label(String(localized: "Import", bundle: .module), systemImage: "plus")
                }
                .accessibilityIdentifier("library.import")
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: LibraryRoute) -> some View {
        switch route {
        case .allTracks: AllTracksView(context: context)
        case .artists: ArtistsView(context: context)
        case .albums: AlbumsView(context: context)
        case .playlists: PlaylistsView(context: context)
        case let .group(id): TrackGroupView(context: context, groupID: id)
        case let .playlist(id): PlaylistDetailView(context: context, playlistID: id)
        }
    }
}
