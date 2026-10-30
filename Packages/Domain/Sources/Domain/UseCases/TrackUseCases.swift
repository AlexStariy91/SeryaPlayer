import Foundation

/// Deletes tracks from the library and removes their audio files.
/// File removal is best effort: a missing file never blocks deleting the record.
public struct DeleteTracksUseCase: Sendable {
    private let tracks: any TrackRepository
    private let files: any FileStoring

    public init(tracks: any TrackRepository, files: any FileStoring) {
        self.tracks = tracks
        self.files = files
    }

    public func callAsFunction(_ doomed: [Track]) async throws {
        guard !doomed.isEmpty else { return }
        try await tracks.delete(ids: doomed.map(\.id))
        for track in doomed {
            try? await files.deleteFile(relativePath: track.relativePath)
        }
    }
}

/// Edits a track's tags in the database only; the audio file is never rewritten.
public struct EditTrackTagsUseCase: Sendable {
    public struct Changes: Sendable, Equatable {
        public var title: String
        public var artist: String
        public var album: String
        /// New artwork image data; `nil` keeps the current artwork.
        public var artworkData: Data?

        public init(title: String, artist: String, album: String, artworkData: Data? = nil) {
            self.title = title
            self.artist = artist
            self.album = album
            self.artworkData = artworkData
        }
    }

    private let tracks: any TrackRepository
    private let artwork: any ArtworkStoring

    public init(tracks: any TrackRepository, artwork: any ArtworkStoring) {
        self.tracks = tracks
        self.artwork = artwork
    }

    /// Returns the updated track. A blank title is rejected with `DomainError.emptyName`.
    @discardableResult
    public func callAsFunction(_ track: Track, changes: Changes) async throws -> Track {
        let title = changes.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw DomainError.emptyName }
        var updated = track
        updated.title = title
        updated.artist = changes.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.album = changes.album.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = changes.artworkData {
            updated.artworkKey = try await artwork.store(data)
        }
        try await tracks.update(updated)
        return updated
    }
}

/// Moves tracks into a folder (`nil` = library root).
public struct MoveTracksUseCase: Sendable {
    private let tracks: any TrackRepository

    public init(tracks: any TrackRepository) {
        self.tracks = tracks
    }

    public func callAsFunction(_ trackIDs: [Track.ID], toFolder folderID: Folder.ID?) async throws {
        guard !trackIDs.isEmpty else { return }
        try await tracks.move(trackIDs: trackIDs, toFolder: folderID)
    }
}
