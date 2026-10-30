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

func makeTracks(_ count: Int) -> [Track] {
    (0 ..< count).map { Track.fixture("Track \($0)") }
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
