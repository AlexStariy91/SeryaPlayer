import Domain
import DomainTestSupport
import Foundation
@testable import LibraryFeature

/// `LibraryDependencies` built from `DomainTestSupport` fakes, with handles for assertions.
@MainActor
struct TestDependencies: LibraryDependencies {
    let tracks: InMemoryTrackRepository
    let playlists = InMemoryPlaylistRepository()
    let folders: InMemoryFolderRepository
    let settings: InMemorySettingsRepository
    let files = FakeFileStore()
    let metadata = FakeMetadataReader()
    let artwork = FakeArtworkStore()
    let spy = SpyPlayer()

    init(tracks: [Track] = [], folders: [Folder] = [], settings: AppSettings = AppSettings()) {
        let folderRepository = InMemoryFolderRepository(folders: folders)
        self.folders = folderRepository
        self.tracks = InMemoryTrackRepository(tracks: tracks, folders: folderRepository)
        self.settings = InMemorySettingsRepository(settings: settings)
    }

    var trackRepository: any TrackRepository {
        tracks
    }

    var playlistRepository: any PlaylistRepository {
        playlists
    }

    var folderRepository: any FolderRepository {
        folders
    }

    var settingsRepository: any SettingsRepository {
        settings
    }

    var fileStore: any FileStoring {
        files
    }

    var artworkStore: any ArtworkStoring {
        artwork
    }

    var player: any PlaybackControlling {
        spy
    }

    var importTracks: ImportTracksUseCase {
        ImportTracksUseCase(files: files, metadata: metadata, artwork: artwork, tracks: tracks, folders: folders)
    }

    func makeContext() -> LibraryContext {
        LibraryContext(dependencies: self)
    }
}

/// Records every call the Library makes on the player.
@MainActor
final class SpyPlayer: PlaybackControlling {
    struct Play: Equatable {
        var titles: [String]
        var index: Int
        var shuffled: Bool
    }

    var snapshot = PlaybackSnapshot()
    var currentTime: TimeInterval = 0
    private(set) var plays: [Play] = []
    private(set) var playedNext: [[Track]] = []
    private(set) var queued: [[Track]] = []

    func snapshots() -> AsyncStream<PlaybackSnapshot> {
        AsyncStream { $0.yield(snapshot) }
    }

    func play(_ tracks: [Track], startingAt index: Int, shuffled: Bool) {
        plays.append(Play(titles: tracks.map(\.title), index: index, shuffled: shuffled))
    }

    func playNext(_ tracks: [Track]) {
        playedNext.append(tracks)
    }

    func addToQueue(_ tracks: [Track]) {
        queued.append(tracks)
    }

    func togglePlayPause() {}
    func next() {}
    func previous() {}
    func seek(to _: TimeInterval) {}
    func toggleShuffle() {}
    func cycleRepeatMode() {}
    func moveQueueItems(fromOffsets _: IndexSet, toOffset _: Int) {}
    func jump(toQueueIndex _: Int) {}
    func removeQueueItems(atOffsets _: IndexSet) {}
    func setRate(_: Float) {}
    func apply(_: EQSettings) {}
    func restore() async {}
    func persist() async {}
}

extension Track {
    /// A fixture with the fields sorting and grouping care about.
    static func make(
        _ title: String,
        artist: String = "Artist",
        album: String = "Album",
        trackNumber: Int? = nil,
        duration: TimeInterval = 200,
        added: TimeInterval = 0,
        playCount: Int = 0,
        lastPlayed: TimeInterval? = nil,
        artworkKey: String? = nil
    ) -> Track {
        Track(
            title: title,
            artist: artist,
            album: album,
            trackNumber: trackNumber,
            duration: duration,
            relativePath: "Media/\(title).mp3",
            originalFileName: "\(title).mp3",
            fileSize: 1000,
            contentHash: title,
            artworkKey: artworkKey,
            dateAdded: Date(timeIntervalSince1970: added),
            playCount: playCount,
            lastPlayedAt: lastPlayed.map { Date(timeIntervalSince1970: $0) }
        )
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
