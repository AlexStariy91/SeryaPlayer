import Domain
import DomainTestSupport
import Foundation
@testable import Playback
import Testing

@MainActor
struct PlaybackRateAndPositionTests {
    let engine = MockPlaybackEngine()
    let nowPlaying = MockNowPlaying()
    let positions = InMemoryTrackPositionRepository()
    let stateRepository = InMemoryPlaybackStateRepository()
    /// Two audiobook-length tracks and one short one.
    let long: [Track]
    let short: Track

    init() {
        long = (0 ..< 2).map { index in
            var track = Track.fixture("Book \(index)")
            track.duration = 3600
            return track
        }
        short = Track.fixture("Song")
    }

    func makeService() -> DefaultPlaybackService {
        DefaultPlaybackService(
            engine: engine,
            trackRepository: InMemoryTrackRepository(tracks: long + [short]),
            stateRepository: stateRepository,
            positionRepository: positions,
            nowPlaying: nowPlaying,
            urlForTrack: fileURL(for:)
        )
    }

    // MARK: - Rate

    @Test func rateIsPublishedToNowPlayingAsRateAndDefaultRate() {
        let service = makeService()
        service.setRate(1.5)
        service.play([short], startingAt: 0, shuffled: false)

        #expect(engine.rate == 1.5)
        #expect(nowPlaying.last?.rate == 1.5)
        #expect(nowPlaying.last?.defaultRate == 1.5)

        service.togglePlayPause()
        #expect(nowPlaying.last?.rate == 0)
        #expect(nowPlaying.last?.defaultRate == 1.5)
    }

    @Test func rateAppliesToEveryTrackAndSnapsToAnOption() {
        let service = makeService()
        service.setRate(1.74)
        #expect(service.snapshot.rate == 1.75)

        service.play([short] + long, startingAt: 0, shuffled: false)
        service.next()

        #expect(engine.rate == 1.75)
        #expect(service.snapshot.rate == 1.75)
    }

    // MARK: - Position memory

    @Test func longTrackIsSavedWhenAnotherOneStartsAndResumesLater() {
        let service = makeService()
        service.play(long, startingAt: 0, shuffled: false)
        engine.currentTime = 600

        service.next()
        #expect(positions.position(for: long[0].id) == 600)
        #expect(engine.loadPositions.last == 0)

        service.jump(toQueueIndex: 0)
        #expect(engine.loadPositions.last == 600)
    }

    @Test func replacingTheQueueSavesTheCurrentLongTrack() {
        let service = makeService()
        service.play(long, startingAt: 0, shuffled: false)
        engine.currentTime = 1200

        service.play([short], startingAt: 0, shuffled: false)
        service.play(long, startingAt: 0, shuffled: false)

        #expect(engine.loadPositions.last == 1200)
    }

    @Test func goingToBackgroundSavesThePosition() async {
        let service = makeService()
        service.play(long, startingAt: 0, shuffled: false)
        engine.currentTime = 900

        await service.persist()

        #expect(positions.position(for: long[0].id) == 900)
    }

    @Test func shortTracksAreNeverRemembered() {
        let service = makeService()
        service.play([short, long[0]], startingAt: 0, shuffled: false)
        engine.currentTime = 100
        service.next()

        #expect(positions.position(for: short.id) == nil)
        service.jump(toQueueIndex: 0)
        #expect(engine.loadPositions.last == 0)
    }

    @Test func positionsNearTheStartAreClearedNotResumed() {
        let service = makeService()
        positions.save(position: 600, for: long[0].id)
        service.play(long, startingAt: 0, shuffled: false)
        #expect(engine.loadPositions.last == 600)

        engine.currentTime = 9.9
        service.next()

        #expect(positions.position(for: long[0].id) == nil)
        service.jump(toQueueIndex: 0)
        #expect(engine.loadPositions.last == 0)
    }

    @Test func positionsNearTheEndAreClearedNotResumed() {
        let service = makeService()
        service.play(long, startingAt: 0, shuffled: false)
        engine.currentTime = 3600 - 29

        service.next()

        #expect(positions.position(for: long[0].id) == nil)
    }

    @Test func staleNearEndEntryIsIgnoredAndCleared() {
        positions.save(position: 3590, for: long[0].id)
        let service = makeService()

        service.play(long, startingAt: 0, shuffled: false)

        #expect(engine.loadPositions.last == 0)
        #expect(positions.position(for: long[0].id) == nil)
    }

    @Test func boundaryPositionsAreKept() {
        let service = makeService()
        service.play(long, startingAt: 0, shuffled: false)
        engine.currentTime = 10
        service.next()
        #expect(positions.position(for: long[0].id) == 10)

        service.jump(toQueueIndex: 0)
        engine.currentTime = 3570
        service.next()
        #expect(positions.position(for: long[0].id) == 3570)
    }

    @Test func seekingToTheStartForgetsThePosition() {
        let service = makeService()
        positions.save(position: 600, for: long[0].id)
        service.play(long, startingAt: 0, shuffled: false)

        service.seek(to: 0)
        service.next()

        #expect(positions.position(for: long[0].id) == nil)
    }

    @Test func finishingATrackForgetsItsPosition() async {
        let service = makeService()
        positions.save(position: 600, for: long[0].id)
        service.play(long, startingAt: 0, shuffled: false)
        engine.currentTime = 3600

        engine.send(.didFinish(generation: engine.generation))

        #expect(await waitUntil { service.snapshot.currentIndex == 1 })
        #expect(positions.position(for: long[0].id) == nil)
    }

    @Test func autoAdvanceResumesTheNextLongTrack() async {
        positions.save(position: 1800, for: long[1].id)
        let service = makeService()
        service.play(long, startingAt: 0, shuffled: false)

        engine.send(.didFinish(generation: engine.generation))

        #expect(await waitUntil { service.snapshot.currentIndex == 1 })
        #expect(engine.loadPositions.last == 1800)
    }

    @Test func restoreKeepsTheSessionPositionNotTheMemory() async {
        positions.save(position: 600, for: long[0].id)
        var state = PlaybackState()
        state.queue = long.map(\.id)
        state.originalQueue = long.map(\.id)
        state.currentIndex = 0
        state.position = 100
        try? await stateRepository.save(state)
        let service = makeService()

        await service.restore()

        #expect(engine.loadPositions.last == 100)
    }

    // MARK: - Cleanup

    @Test func deletingTracksForgetsTheirPositions() async {
        let service = makeService()
        positions.save(position: 600, for: long[0].id)
        positions.save(position: 700, for: long[1].id)

        await service.removeFromQueue(trackIDs: [long[0].id])

        #expect(positions.position(for: long[0].id) == nil)
        #expect(positions.position(for: long[1].id) == 700)
    }

    @Test func deletingTheCurrentTrackDoesNotSaveItAgain() async {
        let service = makeService()
        service.play(long, startingAt: 0, shuffled: false)
        engine.currentTime = 600

        await service.removeFromQueue(trackIDs: [long[0].id])

        #expect(positions.position(for: long[0].id) == nil)
        #expect(service.snapshot.nowPlaying?.id == long[1].id)
    }
}
