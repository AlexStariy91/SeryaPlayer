#if DEBUG
    import Domain
    import Foundation

    /// Inline fakes for `#Preview`s: fixed data, writes are ignored.
    @MainActor
    struct PreviewDependencies: LibraryDependencies {
        var trackRepository: any TrackRepository
        var playlistRepository: any PlaylistRepository = PreviewPlaylistRepository()
        var folderRepository: any FolderRepository = PreviewFolderRepository()
        var settingsRepository: any SettingsRepository = PreviewSettingsRepository()
        var fileStore: any FileStoring = PreviewFileStore()
        var artworkStore: any ArtworkStoring = PreviewArtworkStore()
        var player: any PlaybackControlling = PreviewPlayer()
        var importTracks: ImportTracksUseCase

        init(tracks: [Track] = PreviewData.tracks) {
            let repository = PreviewTrackRepository(tracks: tracks)
            trackRepository = repository
            importTracks = ImportTracksUseCase(
                files: PreviewFileStore(),
                metadata: PreviewMetadataReader(),
                artwork: PreviewArtworkStore(),
                tracks: repository,
                folders: PreviewFolderRepository()
            )
        }
    }

    enum PreviewData {
        static let tracks: [Track] = [
            ("Midnight City", "M83", "Hurry Up, We're Dreaming"),
            ("Wait", "M83", "Hurry Up, We're Dreaming"),
            ("Teardrop", "Massive Attack", "Mezzanine"),
            ("Angel", "Massive Attack", "Mezzanine"),
            ("Svefn-g-englar", "Sigur Rós", "Ágætis byrjun"),
            ("Nude", "Radiohead", "In Rainbows"),
        ].enumerated().map { index, item in
            Track(
                title: item.0,
                artist: item.1,
                album: item.2,
                trackNumber: index + 1,
                duration: Double(180 + index * 37),
                relativePath: "Media/\(index).mp3",
                originalFileName: "\(item.0).mp3",
                fileSize: 1000,
                contentHash: item.0,
                dateAdded: Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 3600),
                playCount: index,
                lastPlayedAt: index.isMultiple(of: 2) ? Date(timeIntervalSince1970: 1_700_100_000 + Double(index)) : nil
            )
        }
    }

    private func once<T: Sendable>(_ value: T) -> AsyncStream<T> {
        AsyncStream { continuation in
            continuation.yield(value)
        }
    }

    struct PreviewTrackRepository: TrackRepository {
        let tracks: [Track]

        func observeTracks(sortedBy _: TrackSort) -> AsyncStream<[Track]> {
            once(tracks)
        }

        func tracks(ids: [Track.ID]) async throws -> [Track] {
            tracks.filter { ids.contains($0.id) }
        }

        func tracks(inFolder _: Folder.ID?, includeSubfolders _: Bool) async throws -> [Track] {
            tracks
        }

        func search(_ query: String, sortedBy _: TrackSort) async throws -> [Track] {
            TrackSearchIndex.filter(tracks, query: query, scope: .all)
        }

        func track(withContentHash _: String) async throws -> Track? {
            nil
        }

        func add(_: [Track]) async throws {}
        func update(_: Track) async throws {}
        func move(trackIDs _: [Track.ID], toFolder _: Folder.ID?) async throws {}
        func delete(ids _: [Track.ID]) async throws {}
        func markPlayed(id _: Track.ID, at _: Date) async throws {}
    }

    struct PreviewPlaylistRepository: PlaylistRepository {
        func observePlaylists() -> AsyncStream<[Playlist]> {
            once([Playlist(name: "Late Night"), Playlist(name: "Focus")])
        }

        func observeEntries(of _: Playlist.ID) -> AsyncStream<[PlaylistEntry]> {
            once(PreviewData.tracks.prefix(4).enumerated().map { PlaylistEntry(trackID: $1.id, sortIndex: $0) })
        }

        func create(_: Playlist) async throws {}
        func update(_: Playlist) async throws {}
        func delete(id _: Playlist.ID) async throws {}
        func append(trackIDs _: [Track.ID], to _: Playlist.ID) async throws {}
        func moveEntries(fromOffsets _: IndexSet, toOffset _: Int, in _: Playlist.ID) async throws {}
        func removeEntries(ids _: [PlaylistEntry.ID]) async throws {}
    }

    struct PreviewFolderRepository: FolderRepository {
        func observeFolders() -> AsyncStream<[Folder]> {
            once([Folder(name: "Rock"), Folder(name: "Jazz", sortIndex: 1)])
        }

        func folders() async throws -> [Folder] {
            []
        }

        func create(_: Folder) async throws {}
        func update(_: Folder) async throws {}
        func delete(id _: Folder.ID) async throws {}
    }

    struct PreviewSettingsRepository: SettingsRepository {
        func load() -> AppSettings {
            AppSettings()
        }

        func save(_: AppSettings) {}

        func observe() -> AsyncStream<AppSettings> {
            once(AppSettings())
        }
    }

    struct PreviewFileStore: FileStoring {
        func contentHash(of url: URL) async throws -> String {
            url.lastPathComponent
        }

        func importFile(from url: URL) async throws -> StoredFile {
            StoredFile(relativePath: url.lastPathComponent, originalFileName: url.lastPathComponent, fileSize: 0, contentHash: "")
        }

        func url(forRelativePath path: String) -> URL {
            URL(fileURLWithPath: path)
        }

        func deleteFile(relativePath _: String) async throws {}

        func librarySize() async -> Int64 {
            0
        }

        func pendingInboxFiles() async -> [URL] {
            []
        }

        func removeFromInbox(_: URL) async throws {}
    }

    struct PreviewMetadataReader: MetadataReading {
        func read(from _: URL) async throws -> TrackMetadata {
            TrackMetadata(duration: 180)
        }
    }

    struct PreviewArtworkStore: ArtworkStoring {
        func store(_: Data) async throws -> String {
            ""
        }

        func url(for _: String, size _: ArtworkSize) async -> URL? {
            nil
        }

        func clearCache() async throws {}
    }

    @MainActor
    final class PreviewPlayer: PlaybackControlling {
        var snapshot = PlaybackSnapshot()
        var currentTime: TimeInterval = 0

        func snapshots() -> AsyncStream<PlaybackSnapshot> {
            once(snapshot)
        }

        func play(_: [Track], startingAt _: Int, shuffled _: Bool) {}
        func togglePlayPause() {}
        func next() {}
        func previous() {}
        func seek(to _: TimeInterval) {}
        func toggleShuffle() {}
        func cycleRepeatMode() {}
        func playNext(_: [Track]) {}
        func addToQueue(_: [Track]) {}
        func moveQueueItems(fromOffsets _: IndexSet, toOffset _: Int) {}
        func removeQueueItems(atOffsets _: IndexSet) {}
        func setRate(_: Float) {}
        func apply(_: EQSettings) {}
        func restore() async {}
        func persist() async {}
    }
#endif
