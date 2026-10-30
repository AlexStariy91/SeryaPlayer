import Foundation

public struct ObservePlaylistsUseCase: Sendable {
    private let playlists: any PlaylistRepository

    public init(playlists: any PlaylistRepository) {
        self.playlists = playlists
    }

    public func callAsFunction() -> AsyncStream<[Playlist]> {
        playlists.observePlaylists()
    }

    public func entries(of playlistID: Playlist.ID) -> AsyncStream<[PlaylistEntry]> {
        playlists.observeEntries(of: playlistID)
    }
}

public struct CreatePlaylistUseCase: Sendable {
    private let playlists: any PlaylistRepository

    public init(playlists: any PlaylistRepository) {
        self.playlists = playlists
    }

    /// Creates a playlist, optionally with initial tracks.
    @discardableResult
    public func callAsFunction(name: String, trackIDs: [Track.ID] = []) async throws -> Playlist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.emptyName }
        let playlist = Playlist(name: trimmed)
        try await playlists.create(playlist)
        if !trackIDs.isEmpty {
            try await playlists.append(trackIDs: trackIDs, to: playlist.id)
        }
        return playlist
    }
}

public struct RenamePlaylistUseCase: Sendable {
    private let playlists: any PlaylistRepository

    public init(playlists: any PlaylistRepository) {
        self.playlists = playlists
    }

    public func callAsFunction(_ playlist: Playlist, to name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.emptyName }
        var renamed = playlist
        renamed.name = trimmed
        try await playlists.update(renamed)
    }
}

public struct DeletePlaylistUseCase: Sendable {
    private let playlists: any PlaylistRepository

    public init(playlists: any PlaylistRepository) {
        self.playlists = playlists
    }

    public func callAsFunction(id: Playlist.ID) async throws {
        try await playlists.delete(id: id)
    }
}

public struct AddTracksToPlaylistUseCase: Sendable {
    private let playlists: any PlaylistRepository

    public init(playlists: any PlaylistRepository) {
        self.playlists = playlists
    }

    /// Appends to the end. A track may appear in a playlist more than once.
    public func callAsFunction(trackIDs: [Track.ID], to playlistID: Playlist.ID) async throws {
        guard !trackIDs.isEmpty else { return }
        try await playlists.append(trackIDs: trackIDs, to: playlistID)
    }
}

public struct EditPlaylistEntriesUseCase: Sendable {
    private let playlists: any PlaylistRepository

    public init(playlists: any PlaylistRepository) {
        self.playlists = playlists
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int, in playlistID: Playlist.ID) async throws {
        try await playlists.moveEntries(fromOffsets: source, toOffset: destination, in: playlistID)
    }

    public func remove(entryIDs: [PlaylistEntry.ID]) async throws {
        guard !entryIDs.isEmpty else { return }
        try await playlists.removeEntries(ids: entryIDs)
    }
}
