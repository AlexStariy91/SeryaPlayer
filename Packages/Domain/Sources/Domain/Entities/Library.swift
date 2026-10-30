import Foundation

public struct Track: Identifiable, Hashable, Sendable {
    public typealias ID = UUID

    public let id: ID
    public var title: String
    public var artist: String
    public var album: String
    public var albumArtist: String?
    public var trackNumber: Int?
    public var duration: TimeInterval
    /// Path relative to the library root (`Media/<uuid>.<ext>`). Absolute paths are never stored.
    public var relativePath: String
    public var originalFileName: String
    public var fileSize: Int64
    /// File size + SHA-256 of the file head; used for duplicate detection.
    public var contentHash: String
    public var artworkKey: String?
    public var folderID: Folder.ID?
    public var dateAdded: Date
    public var playCount: Int
    public var lastPlayedAt: Date?

    public init(
        id: ID = UUID(),
        title: String,
        artist: String,
        album: String,
        albumArtist: String? = nil,
        trackNumber: Int? = nil,
        duration: TimeInterval,
        relativePath: String,
        originalFileName: String,
        fileSize: Int64,
        contentHash: String,
        artworkKey: String? = nil,
        folderID: Folder.ID? = nil,
        dateAdded: Date = .now,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.trackNumber = trackNumber
        self.duration = duration
        self.relativePath = relativePath
        self.originalFileName = originalFileName
        self.fileSize = fileSize
        self.contentHash = contentHash
        self.artworkKey = artworkKey
        self.folderID = folderID
        self.dateAdded = dateAdded
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
    }
}

public struct Folder: Identifiable, Hashable, Sendable {
    public typealias ID = UUID

    public let id: ID
    public var name: String
    public var parentID: ID?
    public var sortIndex: Int
    public var createdAt: Date

    public init(id: ID = UUID(), name: String, parentID: ID? = nil, sortIndex: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.parentID = parentID
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}

public struct Playlist: Identifiable, Hashable, Sendable {
    public typealias ID = UUID

    public let id: ID
    public var name: String
    public var createdAt: Date
    public var coverArtworkKey: String?

    public init(id: ID = UUID(), name: String, createdAt: Date = .now, coverArtworkKey: String? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.coverArtworkKey = coverArtworkKey
    }
}

/// A track may appear in a playlist more than once; order is defined by `sortIndex`.
public struct PlaylistEntry: Identifiable, Hashable, Sendable {
    public typealias ID = UUID

    public let id: ID
    public var trackID: Track.ID
    public var sortIndex: Int

    public init(id: ID = UUID(), trackID: Track.ID, sortIndex: Int) {
        self.id = id
        self.trackID = trackID
        self.sortIndex = sortIndex
    }
}

public struct TrackSort: Hashable, Sendable, Codable {
    public enum Field: String, CaseIterable, Sendable, Codable {
        case title, artist, dateAdded, duration, playCount
    }

    public var field: Field
    public var ascending: Bool

    public init(field: Field = .title, ascending: Bool = true) {
        self.field = field
        self.ascending = ascending
    }
}

/// What happens to tracks when a folder is deleted. Decided by a use case, not a delete rule.
public enum FolderDeletionPolicy: Sendable {
    case deleteTracks
    case moveTracksToRoot
}

public struct ImportResult: Sendable, Equatable {
    public var added: [Track]
    public var duplicates: [String]
    public var unsupported: [String]
    public var failed: [String]

    public init(added: [Track] = [], duplicates: [String] = [], unsupported: [String] = [], failed: [String] = []) {
        self.added = added
        self.duplicates = duplicates
        self.unsupported = unsupported
        self.failed = failed
    }
}

public struct ImportProgress: Sendable, Equatable {
    public var completed: Int
    public var total: Int

    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
    }
}
