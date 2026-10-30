import Domain
import SwiftUI

/// Everything the Folders tab needs. `AppContainer` conforms; property names match the container's.
@MainActor
public protocol FoldersDependencies {
    var folderRepository: any FolderRepository { get }
    var trackRepository: any TrackRepository { get }
    /// Deletes audio files when tracks (or folders with their tracks) are deleted.
    var fileStore: any FileStoring { get }
    var artworkStore: any ArtworkStoring { get }
    var player: any PlaybackControlling { get }
}

public enum FoldersFeature {
    /// The Folders tab: a `NavigationStack` titled "Folders" that drills down into subfolders.
    @MainActor
    public static func makeRootView(dependencies: some FoldersDependencies) -> some View {
        FoldersRootView(context: FoldersContext(dependencies: dependencies))
    }
}
