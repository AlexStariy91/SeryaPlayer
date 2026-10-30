import Domain
import Foundation

@MainActor
final class MockPlaybackEngine: PlaybackEngine {
    let events: AsyncStream<PlaybackEngineEvent>
    private let continuation: AsyncStream<PlaybackEngineEvent>.Continuation

    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 180
    private(set) var isPlaying = false

    private(set) var generation = 0
    private(set) var loadedURLs: [URL] = []
    private(set) var loadPositions: [TimeInterval] = []
    private(set) var seeks: [TimeInterval] = []
    private(set) var rate: Float = 1
    private(set) var equalizer: EQSettings?
    var failingURLs: Set<URL> = []

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    func send(_ event: PlaybackEngineEvent) {
        if case .interruptionBegan = event {
            isPlaying = false
        }
        if case .didFinish = event {
            isPlaying = false
        }
        continuation.yield(event)
    }

    func load(url: URL, startingAt position: TimeInterval) throws -> Int {
        if failingURLs.contains(url) {
            throw URLError(.cannotOpenFile)
        }
        loadedURLs.append(url)
        loadPositions.append(position)
        currentTime = position
        isPlaying = false
        generation += 1
        return generation
    }

    func play() throws {
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
        currentTime = 0
    }

    func seek(to time: TimeInterval) {
        seeks.append(time)
        currentTime = time
    }

    func setRate(_ rate: Float) {
        self.rate = rate
    }

    func apply(_ equalizer: EQSettings) {
        self.equalizer = equalizer
    }
}

@MainActor
final class MockNowPlaying: NowPlayingPublishing {
    private(set) var updates: [NowPlayingInfo] = []
    private(set) var clearCount = 0

    var last: NowPlayingInfo? {
        updates.last
    }

    func update(_ info: NowPlayingInfo) {
        updates.append(info)
    }

    func clear() {
        clearCount += 1
    }
}

actor InMemoryTrackRepository: TrackRepository {
    private(set) var tracks: [Track.ID: Track]
    private(set) var playedIDs: [Track.ID] = []

    init(_ tracks: [Track]) {
        self.tracks = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
    }

    func track(id: Track.ID) -> Track? {
        tracks[id]
    }

    nonisolated func observeTracks(sortedBy _: TrackSort) -> AsyncStream<[Track]> {
        AsyncStream { $0.finish() }
    }

    func tracks(ids: [Track.ID]) async throws -> [Track] {
        ids.compactMap { tracks[$0] }
    }

    func tracks(inFolder folderID: Folder.ID?, includeSubfolders _: Bool) async throws -> [Track] {
        tracks.values.filter { $0.folderID == folderID }
    }

    func search(_: String, sortedBy _: TrackSort) async throws -> [Track] {
        []
    }

    func track(withContentHash hash: String) async throws -> Track? {
        tracks.values.first { $0.contentHash == hash }
    }

    func add(_ newTracks: [Track]) async throws {
        for track in newTracks {
            tracks[track.id] = track
        }
    }

    func update(_ track: Track) async throws {
        tracks[track.id] = track
    }

    func move(trackIDs: [Track.ID], toFolder folderID: Folder.ID?) async throws {
        for id in trackIDs {
            tracks[id]?.folderID = folderID
        }
    }

    func delete(ids: [Track.ID]) async throws {
        for id in ids {
            tracks[id] = nil
        }
    }

    func markPlayed(id: Track.ID, at date: Date) async throws {
        playedIDs.append(id)
        tracks[id]?.playCount += 1
        tracks[id]?.lastPlayedAt = date
    }
}

actor InMemoryPlaybackStateRepository: PlaybackStateRepository {
    private(set) var state: PlaybackState?

    init(_ state: PlaybackState? = nil) {
        self.state = state
    }

    func load() async -> PlaybackState? {
        state
    }

    func save(_ state: PlaybackState) async throws {
        self.state = state
    }
}

/// SplitMix64: deterministic shuffles in tests.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func makeTracks(_ count: Int) -> [Track] {
    (0 ..< count).map { index in
        Track(
            title: "Track \(index)",
            artist: "Artist",
            album: "Album",
            duration: 180,
            relativePath: "Media/\(index).mp3",
            originalFileName: "\(index).mp3",
            fileSize: 1000,
            contentHash: "hash-\(index)"
        )
    }
}

func fileURL(for track: Track) -> URL {
    URL(fileURLWithPath: "/library").appendingPathComponent(track.relativePath)
}

/// Lets the service's event loop and fire-and-forget tasks run until `condition` holds.
@MainActor
func waitUntil(_ condition: @MainActor () async -> Bool) async -> Bool {
    for _ in 0 ..< 1000 {
        if await condition() {
            return true
        }
        await Task.yield()
    }
    return await condition()
}
