import Domain
import DomainTestSupport
import Foundation
@testable import Playback
import Testing

@MainActor
struct DefaultPlaybackServiceTests {
    let tracks = makeTracks(5)
    let engine = MockPlaybackEngine()
    let nowPlaying = MockNowPlaying()
    let trackRepository: InMemoryTrackRepository
    let stateRepository = InMemoryPlaybackStateRepository()

    init() {
        trackRepository = InMemoryTrackRepository(tracks: tracks)
    }

    func makeService(seed: UInt64 = 42) -> DefaultPlaybackService {
        DefaultPlaybackService(
            engine: engine,
            trackRepository: trackRepository,
            stateRepository: stateRepository,
            nowPlaying: nowPlaying,
            urlForTrack: fileURL(for:),
            randomGenerator: SeededGenerator(seed: seed),
            now: { Date(timeIntervalSince1970: 1000) }
        )
    }

    func playCount(of track: Track) -> Int? {
        trackRepository.snapshot.first { $0.id == track.id }?.playCount
    }

    // MARK: - Starting and auto-advance

    @Test func playLoadsAndStartsTheSelectedTrack() {
        let service = makeService()
        service.play(tracks, startingAt: 2, shuffled: false)

        #expect(engine.loadedURLs == [fileURL(for: tracks[2])])
        #expect(engine.isPlaying)
        #expect(service.snapshot.nowPlaying?.id == tracks[2].id)
        #expect(service.snapshot.isPlaying)
        #expect(service.snapshot.queue.map(\.id) == tracks.map(\.id))
        #expect(service.snapshot.currentIndex == 2)
        #expect(nowPlaying.last?.title == tracks[2].title)
        #expect(nowPlaying.last?.rate == 1)
    }

    @Test func didFinishAdvancesToTheNextTrack() async {
        let service = makeService()
        service.play(tracks, startingAt: 0, shuffled: false)

        engine.send(.didFinish(generation: engine.generation))

        #expect(await waitUntil { service.snapshot.currentIndex == 1 })
        #expect(engine.loadedURLs.last == fileURL(for: tracks[1]))
        #expect(service.snapshot.isPlaying)
    }

    @Test func staleDidFinishFromAnOlderGenerationIsIgnored() async {
        let service = makeService()
        service.play(tracks, startingAt: 0, shuffled: false)
        let firstGeneration = engine.generation
        service.next()
        #expect(service.snapshot.currentIndex == 1)

        engine.send(.didFinish(generation: firstGeneration))
        engine.send(.routeRequiresPause) // a marker: once it's handled, the stale event was too

        #expect(await waitUntil { !service.snapshot.isPlaying })
        #expect(service.snapshot.currentIndex == 1)
        #expect(engine.loadedURLs.count == 2)
    }

    @Test func endOfQueueWithRepeatOffRewindsToTheFirstTrackPaused() async {
        let service = makeService()
        service.play(tracks, startingAt: 4, shuffled: false)

        engine.send(.didFinish(generation: engine.generation))

        #expect(await waitUntil { service.snapshot.currentIndex == 0 })
        #expect(!service.snapshot.isPlaying)
        #expect(!engine.isPlaying)
        #expect(service.snapshot.nowPlaying?.id == tracks[0].id)
    }

    @Test func repeatAllWrapsAroundAtTheEnd() async {
        let service = makeService()
        service.play(tracks, startingAt: 4, shuffled: false)
        service.cycleRepeatMode()
        #expect(service.snapshot.repeatMode == .all)

        engine.send(.didFinish(generation: engine.generation))

        #expect(await waitUntil { service.snapshot.currentIndex == 0 })
        #expect(service.snapshot.isPlaying)
    }

    @Test func repeatOneReplaysTheSameTrackAndCountsEachPlay() async {
        let service = makeService()
        service.play(tracks, startingAt: 1, shuffled: false)
        service.cycleRepeatMode()
        service.cycleRepeatMode()
        #expect(service.snapshot.repeatMode == .one)

        engine.send(.didFinish(generation: engine.generation))

        #expect(await waitUntil { engine.loadedURLs.count == 2 })
        #expect(engine.loadedURLs == [fileURL(for: tracks[1]), fileURL(for: tracks[1])])
        #expect(service.snapshot.isPlaying)
        #expect(await waitUntil { playCount(of: tracks[1]) == 2 })

        // A button press leaves the repeated track.
        service.next()
        #expect(service.snapshot.currentIndex == 2)
    }

    @Test func cycleRepeatModeGoesOffAllOneOff() {
        let service = makeService()
        var modes: [RepeatMode] = []
        for _ in 0 ..< 3 {
            service.cycleRepeatMode()
            modes.append(service.snapshot.repeatMode)
        }
        #expect(modes == [.all, .one, .off])
    }

    // MARK: - Shuffle

    @Test func shuffledPlayStartsWithTheSelectedTrack() {
        let service = makeService()
        service.play(tracks, startingAt: 3, shuffled: true)

        #expect(service.snapshot.isShuffled)
        #expect(service.snapshot.nowPlaying?.id == tracks[3].id)
        #expect(service.snapshot.queue.first?.id == tracks[3].id)
        #expect(Set(service.snapshot.queue.map(\.id)) == Set(tracks.map(\.id)))
        #expect(engine.loadedURLs == [fileURL(for: tracks[3])])
    }

    @Test func togglingShuffleKeepsTheCurrentTrackWithoutReloading() {
        let service = makeService()
        service.play(tracks, startingAt: 2, shuffled: false)

        service.toggleShuffle()
        #expect(service.snapshot.isShuffled)
        #expect(service.snapshot.nowPlaying?.id == tracks[2].id)
        #expect(Set(service.snapshot.queue.map(\.id)) == Set(tracks.map(\.id)))

        service.toggleShuffle()
        #expect(!service.snapshot.isShuffled)
        #expect(service.snapshot.queue.map(\.id) == tracks.map(\.id))
        #expect(service.snapshot.nowPlaying?.id == tracks[2].id)
        #expect(service.snapshot.currentIndex == 2)
        #expect(engine.loadedURLs.count == 1)
    }

    // MARK: - Previous

    @Test func previousBeforeThresholdGoesToThePreviousTrack() {
        let service = makeService()
        service.play(tracks, startingAt: 2, shuffled: false)
        engine.currentTime = 2

        service.previous()

        #expect(service.snapshot.currentIndex == 1)
        #expect(engine.loadedURLs.last == fileURL(for: tracks[1]))
        #expect(service.snapshot.isPlaying)
    }

    @Test func previousAfterThresholdRestartsTheCurrentTrack() {
        let service = makeService()
        service.play(tracks, startingAt: 2, shuffled: false)
        engine.currentTime = QueueEngine.restartThreshold + 1

        service.previous()

        #expect(service.snapshot.currentIndex == 2)
        #expect(engine.loadedURLs.count == 1)
        #expect(engine.seeks == [0])
    }

    // MARK: - Play count

    @Test func trackIsMarkedPlayedOnceWhenPlaybackStarts() async {
        let service = makeService()
        service.play(tracks, startingAt: 0, shuffled: false)
        service.togglePlayPause()
        service.togglePlayPause()

        #expect(await waitUntil { playCount(of: tracks[0]) == 1 })
        for _ in 0 ..< 10 {
            await Task.yield()
        }
        let stored = trackRepository.snapshot.first { $0.id == tracks[0].id }
        #expect(stored?.playCount == 1)
        #expect(stored?.lastPlayedAt == Date(timeIntervalSince1970: 1000))
    }

    // MARK: - Persistence

    @Test func persistAndRestoreResumeThePausedQueueAtTheSavedPosition() async {
        let service = makeService()
        service.play(tracks, startingAt: 0, shuffled: false)
        service.next()
        service.cycleRepeatMode()
        engine.currentTime = 42
        await service.persist()

        let saved = await stateRepository.load()
        #expect(saved?.queue == tracks.map(\.id))
        #expect(saved?.currentIndex == 1)
        #expect(saved?.position == 42)
        #expect(saved?.repeatMode == .all)

        let restoredEngine = MockPlaybackEngine()
        let restored = DefaultPlaybackService(
            engine: restoredEngine,
            trackRepository: trackRepository,
            stateRepository: stateRepository,
            nowPlaying: nowPlaying,
            urlForTrack: fileURL(for:),
            randomGenerator: SeededGenerator(seed: 1)
        )
        await restored.restore()

        #expect(restored.snapshot.nowPlaying?.id == tracks[1].id)
        #expect(!restored.snapshot.isPlaying)
        #expect(!restoredEngine.isPlaying)
        #expect(restored.snapshot.queue.map(\.id) == tracks.map(\.id))
        #expect(restored.snapshot.repeatMode == .all)
        #expect(restoredEngine.loadedURLs == [fileURL(for: tracks[1])])
        #expect(restoredEngine.loadPositions == [42])

        restored.togglePlayPause()
        #expect(restoredEngine.isPlaying)
        #expect(restoredEngine.loadedURLs.count == 1)
    }

    @Test func restoreSkipsTracksDeletedSinceTheLastSave() async throws {
        let ids = tracks.map(\.id)
        try await stateRepository.save(PlaybackState(queue: ids, originalQueue: ids, currentIndex: 3, position: 30))
        try await trackRepository.delete(ids: [tracks[1].id])
        let service = makeService()

        await service.restore()

        #expect(service.snapshot.queue.map(\.id) == ids.filter { $0 != tracks[1].id })
        #expect(service.snapshot.nowPlaying?.id == tracks[3].id)
        #expect(service.snapshot.currentIndex == 2)
        #expect(engine.loadPositions == [30])
    }

    @Test func restoreStartsFromZeroWhenTheCurrentTrackWasDeleted() {
        let ids = tracks.map(\.id)
        let state = PlaybackState(queue: ids, originalQueue: ids, currentIndex: 2, position: 30)
        let available = Set(ids).subtracting([ids[2]])

        let (cleaned, keptPosition) = DefaultPlaybackService.dropMissingTracks(from: state, available: available)

        #expect(!keptPosition)
        #expect(cleaned.position == 0)
        #expect(cleaned.currentIndex == 2)
        #expect(cleaned.queue == [ids[0], ids[1], ids[3], ids[4]])
    }

    // MARK: - Interruptions and routes

    @Test func interruptionWithShouldResumeResumesPlayback() async {
        let service = makeService()
        service.play(tracks, startingAt: 0, shuffled: false)

        engine.send(.interruptionBegan)
        #expect(await waitUntil { !service.snapshot.isPlaying })

        engine.send(.interruptionEnded(shouldResume: true))
        #expect(await waitUntil { service.snapshot.isPlaying })
        #expect(engine.isPlaying)
    }

    @Test func interruptionWithoutShouldResumeStaysPaused() async {
        let service = makeService()
        service.play(tracks, startingAt: 0, shuffled: false)

        engine.send(.interruptionBegan)
        engine.send(.interruptionEnded(shouldResume: false))
        engine.send(.failed(message: "marker"))

        #expect(await waitUntil { nowPlaying.updates.count >= 3 })
        #expect(!service.snapshot.isPlaying)
        #expect(!engine.isPlaying)
    }

    @Test func interruptionWhilePausedDoesNotStartPlayback() async {
        let service = makeService()
        service.play(tracks, startingAt: 0, shuffled: false)
        service.togglePlayPause()

        engine.send(.interruptionBegan)
        engine.send(.interruptionEnded(shouldResume: true))
        engine.send(.failed(message: "marker"))

        #expect(await waitUntil { nowPlaying.updates.count >= 4 })
        #expect(!engine.isPlaying)
        #expect(!service.snapshot.isPlaying)
    }

    @Test func headphoneRemovalPauses() async {
        let service = makeService()
        service.play(tracks, startingAt: 0, shuffled: false)

        engine.send(.routeRequiresPause)

        #expect(await waitUntil { !service.snapshot.isPlaying })
        #expect(!engine.isPlaying)
        #expect(nowPlaying.last?.rate == 0)
    }

    // MARK: - Snapshots, Now Playing, failures

    @Test func everySubscriberReceivesTheCurrentSnapshotAndChanges() async {
        let service = makeService()
        var first = service.snapshots().makeAsyncIterator()
        var second = service.snapshots().makeAsyncIterator()
        #expect(await first.next()?.nowPlaying == nil)
        #expect(await second.next()?.nowPlaying == nil)

        service.play(tracks, startingAt: 1, shuffled: false)

        #expect(await first.next()?.nowPlaying?.id == tracks[1].id)
        #expect(await second.next()?.nowPlaying?.id == tracks[1].id)
    }

    @Test func nowPlayingFollowsPauseSeekAndRate() {
        let service = makeService()
        service.play(tracks, startingAt: 0, shuffled: false)

        service.seek(to: 60)
        #expect(nowPlaying.last?.position == 60)

        service.setRate(1.5)
        #expect(engine.rate == 1.5)
        #expect(nowPlaying.last?.rate == 1.5)
        #expect(service.snapshot.rate == 1.5)

        service.togglePlayPause()
        #expect(nowPlaying.last?.rate == 0)
    }

    @Test func unreadableFileIsSkipped() {
        engine.failingURLs = [fileURL(for: tracks[0])]
        let service = makeService()

        service.play(tracks, startingAt: 0, shuffled: false)

        #expect(service.snapshot.nowPlaying?.id == tracks[1].id)
        #expect(service.snapshot.isPlaying)
    }

    @Test func removingTheCurrentItemLoadsTheNextOne() {
        let service = makeService()
        service.play(tracks, startingAt: 1, shuffled: false)

        service.removeQueueItems(atOffsets: [1])

        #expect(service.snapshot.queue.count == 4)
        #expect(service.snapshot.nowPlaying?.id == tracks[2].id)
        #expect(engine.loadedURLs.last == fileURL(for: tracks[2]))
    }

    @Test func playNextOnAnEmptyQueueStartsPlaying() {
        let service = makeService()

        service.playNext([tracks[3]])

        #expect(service.snapshot.nowPlaying?.id == tracks[3].id)
        #expect(service.snapshot.isPlaying)
    }

    @Test func equalizerSettingsReachTheEngine() {
        let service = makeService()
        let settings = EQSettings(isEnabled: true, gains: Array(repeating: 3, count: EQBands.count), preamp: -3)

        service.apply(settings)

        #expect(engine.equalizer == settings)
    }
}
