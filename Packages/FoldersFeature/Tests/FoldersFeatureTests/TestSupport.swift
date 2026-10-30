import Domain
import DomainTestSupport
@testable import FoldersFeature

/// `FoldersDependencies` built from `DomainTestSupport` fakes, with handles for assertions.
@MainActor
struct TestDependencies: FoldersDependencies {
    let folders: InMemoryFolderRepository
    let tracks: InMemoryTrackRepository
    let files = FakeFileStore()
    let artwork = FakeArtworkStore()
    let playback = FakePlaybackController()

    init(folders: [Folder] = [], tracks: [Track] = []) {
        let folderRepository = InMemoryFolderRepository(folders: folders)
        self.folders = folderRepository
        self.tracks = InMemoryTrackRepository(tracks: tracks, folders: folderRepository)
    }

    var folderRepository: any FolderRepository {
        folders
    }

    var trackRepository: any TrackRepository {
        tracks
    }

    var fileStore: any FileStoring {
        files
    }

    var artworkStore: any ArtworkStoring {
        artwork
    }

    var player: any PlaybackControlling {
        playback
    }

    /// A context whose store has delivered its first values.
    func loadedContext() async -> FoldersContext {
        let context = FoldersContext(dependencies: self)
        let observer = Task { await context.store.observe() }
        _ = await eventually { context.store.isLoaded }
        observer.cancel()
        return context
    }
}

/// Waits until `condition` holds, yielding to let repository streams deliver. Fails after ~1 s.
@MainActor
func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0 ..< 200 {
        if condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}
