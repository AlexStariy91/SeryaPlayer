import Foundation

// MARK: - Files and metadata

public struct StoredFile: Sendable, Equatable {
    public var relativePath: String
    public var originalFileName: String
    public var fileSize: Int64
    public var contentHash: String

    public init(relativePath: String, originalFileName: String, fileSize: Int64, contentHash: String) {
        self.relativePath = relativePath
        self.originalFileName = originalFileName
        self.fileSize = fileSize
        self.contentHash = contentHash
    }
}

public protocol FileStoring: Sendable {
    /// Computes contentHash without copying (to check duplicates before import).
    func contentHash(of url: URL) async throws -> String
    /// Copies the file into `Media/` under a UUID name. Handles security-scoped access itself.
    func importFile(from url: URL) async throws -> StoredFile
    func url(forRelativePath path: String) -> URL
    func deleteFile(relativePath: String) async throws
    func librarySize() async -> Int64
    /// Files waiting for import: the App Group Inbox and Documents/Inbox.
    func pendingInboxFiles() async -> [URL]
    func removeFromInbox(_ url: URL) async throws
}

public struct TrackMetadata: Sendable, Equatable {
    public var title: String?
    public var artist: String?
    public var album: String?
    public var albumArtist: String?
    public var trackNumber: Int?
    public var duration: TimeInterval
    public var artworkData: Data?

    public init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        albumArtist: String? = nil,
        trackNumber: Int? = nil,
        duration: TimeInterval,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.trackNumber = trackNumber
        self.duration = duration
        self.artworkData = artworkData
    }
}

public enum MetadataError: Error, Sendable {
    case unsupportedFormat
    case unreadable
}

public protocol MetadataReading: Sendable {
    /// Throws `MetadataError.unsupportedFormat` if the system cannot play the file.
    func read(from url: URL) async throws -> TrackMetadata
}

public enum ArtworkSize: Sendable {
    case thumbnail // ~120pt, for lists
    case large // for the full player
}

public protocol ArtworkStoring: Sendable {
    /// Stores artwork by content hash and returns its key. Identical artwork is one file.
    func store(_ data: Data) async throws -> String
    func url(for key: String, size: ArtworkSize) async -> URL?
    func clearCache() async throws
}

// MARK: - Playback

public enum PlaybackEngineEvent: Sendable, Equatable {
    /// The file played to the end. `generation` matches the value returned by `load`; the
    /// service uses it to tell a real end from a stop caused by seeking.
    case didFinish(generation: Int)
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    /// Headphones were unplugged or the route changed in a way that requires pausing.
    case routeRequiresPause
    case failed(message: String)
}

/// Low-level engine (AVAudioEngine). Knows nothing about the queue.
@MainActor
public protocol PlaybackEngine: AnyObject {
    var events: AsyncStream<PlaybackEngineEvent> { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }

    /// Loads a file and returns its generation number.
    @discardableResult
    func load(url: URL, startingAt position: TimeInterval) throws -> Int
    func play() throws
    func pause()
    func stop()
    func seek(to time: TimeInterval)
    func setRate(_ rate: Float)
    func apply(_ equalizer: EQSettings)
}

/// What features use. Implemented by `DefaultPlaybackService` in the Playback package.
@MainActor
public protocol PlaybackControlling: AnyObject {
    var snapshot: PlaybackSnapshot { get }
    /// A new stream per subscriber; the current snapshot comes first.
    func snapshots() -> AsyncStream<PlaybackSnapshot>
    var currentTime: TimeInterval { get }

    func play(_ tracks: [Track], startingAt index: Int, shuffled: Bool)
    func togglePlayPause()
    func next()
    /// Past 3 seconds, restarts the current track.
    func previous()
    func seek(to time: TimeInterval)
    func toggleShuffle()
    func cycleRepeatMode()
    func playNext(_ tracks: [Track])
    func addToQueue(_ tracks: [Track])
    func moveQueueItems(fromOffsets source: IndexSet, toOffset destination: Int)
    func removeQueueItems(atOffsets offsets: IndexSet)
    /// Makes the queue item at `index` current and starts playing it. Out-of-range indices are ignored.
    func jump(toQueueIndex index: Int)
    func setRate(_ rate: Float)
    func apply(_ equalizer: EQSettings)

    /// Restores the queue, paused, on launch.
    func restore() async
    /// Persists the state (called when going to background).
    func persist() async
}

public struct NowPlayingInfo: Sendable, Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var artworkURL: URL?
    public var duration: TimeInterval
    public var position: TimeInterval
    public var rate: Float

    public init(title: String, artist: String, album: String, artworkURL: URL?, duration: TimeInterval, position: TimeInterval, rate: Float) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.position = position
        self.rate = rate
    }
}

@MainActor
public protocol NowPlayingPublishing: AnyObject {
    func update(_ info: NowPlayingInfo)
    func clear()
}
