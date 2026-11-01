import Domain
import DomainTestSupport
import Foundation
import Synchronization

/// Records every call. `snapshots()` replays `snapshotsToSend` (or the current snapshot) and finishes,
/// so `observePlayback()` returns once they are applied.
@MainActor
final class RecordingPlayer: PlaybackControlling {
    enum Call: Equatable {
        case togglePlayPause, next, previous, seek(TimeInterval), toggleShuffle, cycleRepeatMode
        case move(IndexSet, Int), remove(IndexSet), jump(Int)
    }

    var snapshot: PlaybackSnapshot
    var snapshotsToSend: [PlaybackSnapshot] = []
    var currentTime: TimeInterval = 0
    private(set) var calls: [Call] = []
    private(set) var rates: [Float] = []

    init(snapshot: PlaybackSnapshot = PlaybackSnapshot()) {
        self.snapshot = snapshot
    }

    func snapshots() -> AsyncStream<PlaybackSnapshot> {
        let values = snapshotsToSend.isEmpty ? [snapshot] : snapshotsToSend
        return AsyncStream { continuation in
            values.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func play(_: [Track], startingAt _: Int, shuffled _: Bool) {}
    func togglePlayPause() {
        calls.append(.togglePlayPause)
    }

    func next() {
        calls.append(.next)
    }

    func previous() {
        calls.append(.previous)
    }

    func seek(to time: TimeInterval) {
        calls.append(.seek(time))
    }

    func toggleShuffle() {
        calls.append(.toggleShuffle)
    }

    func cycleRepeatMode() {
        calls.append(.cycleRepeatMode)
    }

    func playNext(_: [Track]) {}
    func addToQueue(_: [Track]) {}
    func moveQueueItems(fromOffsets source: IndexSet, toOffset destination: Int) {
        calls.append(.move(source, destination))
    }

    func removeQueueItems(atOffsets offsets: IndexSet) {
        calls.append(.remove(offsets))
    }

    func removeFromQueue(trackIDs _: Set<Track.ID>) async {}

    func jump(toQueueIndex index: Int) {
        calls.append(.jump(index))
    }

    func setRate(_ rate: Float) {
        rates.append(rate)
    }

    func apply(_: EQSettings) {}
    func restore() async {}
    func persist() async {}
}

/// Holds the state and records what the view model asks for.
@MainActor
final class StubSleepTimer: SleepTimerControlling {
    private(set) var state: SleepTimerState
    private(set) var started: [SleepTimerOption] = []
    private(set) var cancelCount = 0

    init(state: SleepTimerState = .off) {
        self.state = state
    }

    func states() -> AsyncStream<SleepTimerState> {
        let state = state
        return AsyncStream { continuation in
            continuation.yield(state)
            continuation.finish()
        }
    }

    func start(_ option: SleepTimerOption) {
        started.append(option)
    }

    func cancel() {
        cancelCount += 1
    }
}

/// Returns `/art/<key>-<size>` URLs, or nil for every key when `returnsNil`; counts lookups.
final class StubArtworkStore: ArtworkStoring {
    private let lookups = Mutex(0)
    let returnsNil: Bool

    init(returnsNil: Bool = false) {
        self.returnsNil = returnsNil
    }

    var lookupCount: Int {
        lookups.withLock { $0 }
    }

    func store(_: Data) async throws -> String {
        "key"
    }

    func url(for key: String, size: ArtworkSize) async -> URL? {
        lookups.withLock { $0 += 1 }
        return returnsNil ? nil : URL(fileURLWithPath: "/art/\(key)-\(size == .large ? "large" : "thumb")")
    }

    func clearCache() async throws {}
}

func makeQueue(_ count: Int) -> [Track] {
    (0 ..< count).map { index in
        var track = Track.fixture("Track \(index)", artist: "Artist \(index)")
        track.artworkKey = "art\(index)"
        return track
    }
}

func waitUntil(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0 ..< 1000 {
        if await condition() {
            return true
        }
        await Task.yield()
    }
    return await condition()
}
