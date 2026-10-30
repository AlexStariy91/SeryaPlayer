import Foundation

// Every `observe…` returns a NEW stream per subscriber: the first value is the
// current state, followed by changes. The stream finishes when the task is cancelled.

public protocol TrackRepository: Sendable {
    func observeTracks(sortedBy sort: TrackSort) -> AsyncStream<[Track]>
    func tracks(ids: [Track.ID]) async throws -> [Track]
    func tracks(inFolder folderID: Folder.ID?, includeSubfolders: Bool) async throws -> [Track]
    /// Case- and diacritic-insensitive search over title, artist and album.
    func search(_ query: String, sortedBy sort: TrackSort) async throws -> [Track]
    func track(withContentHash hash: String) async throws -> Track?
    func add(_ tracks: [Track]) async throws
    func update(_ track: Track) async throws
    func move(trackIDs: [Track.ID], toFolder folderID: Folder.ID?) async throws
    func delete(ids: [Track.ID]) async throws
    func markPlayed(id: Track.ID, at date: Date) async throws
}

public protocol FolderRepository: Sendable {
    func observeFolders() -> AsyncStream<[Folder]>
    func folders() async throws -> [Folder]
    func create(_ folder: Folder) async throws
    func update(_ folder: Folder) async throws
    /// Deletes the folder and all subfolders. Does NOT touch tracks; a use case decides their fate first.
    func delete(id: Folder.ID) async throws
}

public protocol PlaylistRepository: Sendable {
    func observePlaylists() -> AsyncStream<[Playlist]>
    func observeEntries(of playlistID: Playlist.ID) -> AsyncStream<[PlaylistEntry]>
    func create(_ playlist: Playlist) async throws
    func update(_ playlist: Playlist) async throws
    func delete(id: Playlist.ID) async throws
    func append(trackIDs: [Track.ID], to playlistID: Playlist.ID) async throws
    func moveEntries(fromOffsets source: IndexSet, toOffset destination: Int, in playlistID: Playlist.ID) async throws
    func removeEntries(ids: [PlaylistEntry.ID]) async throws
}

/// User presets only. Built-in presets live in code (`BuiltInPresets`).
public protocol EQPresetRepository: Sendable {
    func observePresets() -> AsyncStream<[EQPreset]>
    func save(_ preset: EQPreset) async throws
    func delete(id: EQPreset.ID) async throws
}

public protocol SettingsRepository: Sendable {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
    func observe() -> AsyncStream<AppSettings>
}

public protocol PlaybackStateRepository: Sendable {
    func load() async -> PlaybackState?
    func save(_ state: PlaybackState) async throws
}
