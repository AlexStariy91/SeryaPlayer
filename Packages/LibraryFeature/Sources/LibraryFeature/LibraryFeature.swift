import Domain
import SwiftUI

/// Everything the Library tab needs. `AppContainer` conforms; property names match the container's.
@MainActor
public protocol LibraryDependencies {
    var trackRepository: any TrackRepository { get }
    var playlistRepository: any PlaylistRepository { get }
    /// Used by the "Move to Folder…" picker only; folder management lives in FoldersFeature.
    var folderRepository: any FolderRepository { get }
    /// Persists the All Tracks sort order (`AppSettings.librarySort`).
    var settingsRepository: any SettingsRepository { get }
    /// Deletes audio files when tracks are deleted.
    var fileStore: any FileStoring { get }
    var artworkStore: any ArtworkStoring { get }
    var player: any PlaybackControlling { get }
    var importTracks: ImportTracksUseCase { get }
}

public enum LibraryFeature {
    /// The Library tab: a `NavigationStack` titled "Library" with import and settings in the toolbar.
    @MainActor
    public static func makeRootView(
        dependencies: some LibraryDependencies,
        onOpenSettings: @escaping () -> Void
    ) -> some View {
        LibraryRootView(context: LibraryContext(dependencies: dependencies), onOpenSettings: onOpenSettings)
    }
}
