import DesignSystem
import Domain
import SwiftUI

/// The Library tab root: navigation, import, track action sheets and the live store.
struct LibraryRootView: View {
    /// Held in `@State` so a parent re-render (e.g. switching tabs) doesn't rebuild the store.
    @State private var context: LibraryContext
    let onOpenSettings: () -> Void

    @State private var path: [LibraryRoute] = []

    init(context: LibraryContext, onOpenSettings: @escaping () -> Void) {
        _context = State(wrappedValue: context)
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        @Bindable var importer = context.importer
        NavigationStack(path: $path) {
            LibraryHomeView(context: context)
                .navigationTitle(Text("Library", bundle: .module))
                .toolbar { toolbar }
                .navigationDestination(for: LibraryRoute.self, destination: destination)
        }
        .overlay(alignment: .bottom) {
            if let progress = importer.progress {
                ImportProgressBanner(progress: progress)
                    .padding(.bottom, Spacing.xxl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: importer.isImporting)
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
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(String(localized: "Settings", bundle: .module), systemImage: "gearshape", action: onOpenSettings)
                .accessibilityIdentifier("library.settings")
        }
        ToolbarItem(placement: .primaryAction) {
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
            .disabled(context.importer.isImporting)
            .accessibilityIdentifier("library.import")
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
