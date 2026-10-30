import Domain
import Foundation
import Synchronization

/// Fake file storage. Content hash defaults to the file name, so equal names are duplicates;
/// override with `setHash`. Nothing touches the disk.
public final class FakeFileStore: FileStoring {
    private struct State {
        var hashes: [String: String] = [:]
        var failingNames: Set<String> = []
        var imported: [StoredFile] = []
        var deletedPaths: [String] = []
        var inbox: [URL] = []
    }

    private let state = Mutex(State())

    public init() {}

    public func setHash(_ hash: String, forFileNamed name: String) {
        state.withLock { $0.hashes[name] = hash }
    }

    /// `contentHash` / `importFile` throw for these file names.
    public func failImport(of names: Set<String>) {
        state.withLock { $0.failingNames = names }
    }

    public func setInbox(_ urls: [URL]) {
        state.withLock { $0.inbox = urls }
    }

    public var importedFiles: [StoredFile] {
        state.withLock { $0.imported }
    }

    public var deletedPaths: [String] {
        state.withLock { $0.deletedPaths }
    }

    public func contentHash(of url: URL) async throws -> String {
        let name = url.lastPathComponent
        return try state.withLock { state in
            if state.failingNames.contains(name) {
                throw CocoaError(.fileReadUnknown)
            }
            return state.hashes[name] ?? name
        }
    }

    public func importFile(from url: URL) async throws -> StoredFile {
        let name = url.lastPathComponent
        let hash = try await contentHash(of: url)
        let file = StoredFile(
            relativePath: "Media/\(UUID().uuidString).\(url.pathExtension)",
            originalFileName: name,
            fileSize: 1000,
            contentHash: hash
        )
        state.withLock { $0.imported.append(file) }
        return file
    }

    public func url(forRelativePath path: String) -> URL {
        URL(fileURLWithPath: "/fake/library").appendingPathComponent(path)
    }

    public func deleteFile(relativePath: String) async throws {
        state.withLock { $0.deletedPaths.append(relativePath) }
    }

    public func librarySize() async -> Int64 {
        state.withLock { $0.imported.reduce(0) { $0 + $1.fileSize } }
    }

    public func pendingInboxFiles() async -> [URL] {
        state.withLock { $0.inbox }
    }

    public func removeFromInbox(_ url: URL) async throws {
        state.withLock { $0.inbox.removeAll { $0 == url } }
    }
}

/// Fake tag reader keyed by file name. Unknown files get 180 s of silence-and-no-tags.
public final class FakeMetadataReader: MetadataReading {
    private struct State {
        var metadata: [String: TrackMetadata] = [:]
        var unsupported: Set<String> = []
        var unreadable: Set<String> = []
    }

    private let state = Mutex(State())

    public init() {}

    public func set(_ metadata: TrackMetadata, forFileNamed name: String) {
        state.withLock { $0.metadata[name] = metadata }
    }

    public func markUnsupported(_ names: Set<String>) {
        state.withLock { $0.unsupported = names }
    }

    public func markUnreadable(_ names: Set<String>) {
        state.withLock { $0.unreadable = names }
    }

    public func read(from url: URL) async throws -> TrackMetadata {
        let name = url.lastPathComponent
        return try state.withLock { state in
            if state.unsupported.contains(name) {
                throw MetadataError.unsupportedFormat
            }
            if state.unreadable.contains(name) {
                throw MetadataError.unreadable
            }
            return state.metadata[name] ?? TrackMetadata(duration: 180)
        }
    }
}

public final class FakeArtworkStore: ArtworkStoring {
    private let stored = Mutex<[String]>([])

    public init() {}

    public var storedKeys: [String] {
        stored.withLock { $0 }
    }

    public func store(_ data: Data) async throws -> String {
        let key = "art-\(data.count)"
        stored.withLock {
            if !$0.contains(key) {
                $0.append(key)
            }
        }
        return key
    }

    public func url(for key: String, size _: ArtworkSize) async -> URL? {
        URL(fileURLWithPath: "/fake/artwork/\(key)")
    }

    public func clearCache() async throws {
        stored.withLock { $0.removeAll() }
    }
}

/// Records calls; `snapshot` is whatever the test sets.
@MainActor
public final class FakePlaybackController: PlaybackControlling {
    public struct PlayCall: Equatable {
        public var tracks: [Track]
        public var index: Int
        public var shuffled: Bool

        public init(tracks: [Track], index: Int, shuffled: Bool) {
            self.tracks = tracks
            self.index = index
            self.shuffled = shuffled
        }
    }

    public var snapshot = PlaybackSnapshot()
    public var currentTime: TimeInterval = 0
    public private(set) var playCalls: [PlayCall] = []

    public init() {}

    public func snapshots() -> AsyncStream<PlaybackSnapshot> {
        AsyncStream { continuation in
            continuation.yield(snapshot)
            continuation.finish()
        }
    }

    public func play(_ tracks: [Track], startingAt index: Int, shuffled: Bool) {
        playCalls.append(PlayCall(tracks: tracks, index: index, shuffled: shuffled))
    }

    public func togglePlayPause() {}
    public func next() {}
    public func previous() {}
    public func seek(to _: TimeInterval) {}
    public func toggleShuffle() {}
    public func cycleRepeatMode() {}
    public func playNext(_: [Track]) {}
    public func addToQueue(_: [Track]) {}
    public func moveQueueItems(fromOffsets _: IndexSet, toOffset _: Int) {}
    public func removeQueueItems(atOffsets _: IndexSet) {}
    public func setRate(_: Float) {}
    public func apply(_: EQSettings) {}
    public func restore() async {}
    public func persist() async {}
}

public extension Track {
    /// Quick track for tests; the hash defaults to the title.
    static func fixture(
        _ title: String = "Track",
        artist: String = "Artist",
        album: String = "Album",
        folderID: Folder.ID? = nil,
        contentHash: String? = nil,
        dateAdded: Date = Date(timeIntervalSince1970: 0)
    ) -> Track {
        Track(
            title: title,
            artist: artist,
            album: album,
            duration: 200,
            relativePath: "Media/\(title).mp3",
            originalFileName: "\(title).mp3",
            fileSize: 1000,
            contentHash: contentHash ?? title,
            folderID: folderID,
            dateAdded: dateAdded
        )
    }
}

/// Deterministic RNG (SplitMix64) for shuffle tests.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
