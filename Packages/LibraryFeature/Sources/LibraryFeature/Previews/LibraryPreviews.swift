#if DEBUG
    import SwiftUI

    #Preview("Library") {
        LibraryFeature.makeRootView(dependencies: PreviewDependencies()) {}
    }

    #Preview("Library – empty") {
        LibraryFeature.makeRootView(dependencies: PreviewDependencies(tracks: [])) {}
    }

    #Preview("All Tracks") {
        NavigationStack {
            AllTracksView(context: LibraryContext(dependencies: PreviewDependencies()))
        }
    }

    #Preview("Playlist") {
        let context = LibraryContext(dependencies: PreviewDependencies())
        NavigationStack {
            PlaylistDetailView(context: context, playlistID: UUID())
        }
        .task { await context.store.observe() }
    }
#endif
