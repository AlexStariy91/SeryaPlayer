import Domain
import DomainTestSupport
import Foundation
@testable import Playback
import Synchronization
import Testing

/// A clock the test moves by hand: `sleep` returns once `advance` has moved time past its wake-up point.
final class ManualClock: Sendable {
    private let current = Mutex(Date(timeIntervalSince1970: 1000))

    var now: Date {
        current.withLock { $0 }
    }

    func advance(by seconds: TimeInterval) {
        current.withLock { $0 = $0.addingTimeInterval(seconds) }
    }

    @MainActor
    func sleep(for duration: Duration) async throws {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        let wakeUp = now.addingTimeInterval(seconds)
        while now < wakeUp {
            try Task.checkCancellation()
            await Task.yield()
        }
    }
}

@MainActor
struct SleepTimerTests {
    let tracks = makeTracks(3)
    let engine = MockPlaybackEngine()
    let clock = ManualClock()
    let service: DefaultPlaybackService

    init() {
        let clock = clock
        let timer = SleepTimer(engine: engine, now: { clock.now }, sleep: { try await clock.sleep(for: $0) })
        service = DefaultPlaybackService(
            engine: engine,
            trackRepository: InMemoryTrackRepository(tracks: tracks),
            stateRepository: InMemoryPlaybackStateRepository(),
            nowPlaying: MockNowPlaying(),
            urlForTrack: fileURL(for:),
            randomGenerator: SeededGenerator(seed: 1),
            sleepTimer: timer
        )
        service.play(tracks, startingAt: 0, shuffled: false)
    }

    /// Lets the timer's task reach its first `sleep` before the test moves the clock.
    func settle() async {
        for _ in 0 ..< 10 {
            await Task.yield()
        }
    }

    var timer: SleepTimer {
        service.sleepTimer
    }

    @Test func countdownStateCarriesTheDeadline() {
        timer.start(.minutes(15))

        #expect(timer.state == .countdown(deadline: clock.now.addingTimeInterval(900)))
    }

    @Test func pausesAtTheDeadlineAndTurnsOff() async {
        timer.start(.minutes(5))
        await settle()
        clock.advance(by: 289)
        await Task.yield()
        #expect(engine.isPlaying)
        #expect(timer.state.isActive)

        clock.advance(by: 11)

        #expect(await waitUntil { timer.state == .off })
        #expect(!engine.isPlaying)
        #expect(!service.snapshot.isPlaying)
        #expect(engine.volume == 1)
    }

    @Test func fadesTheVolumeOverTheLastSecondsThenRestoresIt() async {
        timer.start(.minutes(5))
        await settle()
        clock.advance(by: 295)

        #expect(await waitUntil { engine.volume < 0.6 && engine.volume > 0.4 })
        #expect(engine.isPlaying)
        clock.advance(by: 4)
        #expect(await waitUntil { engine.volume < 0.2 })
        #expect(engine.isPlaying)
        clock.advance(by: 1)

        #expect(await waitUntil { timer.state == .off })
        let fade = Array(engine.volumes.dropLast())
        #expect(fade == fade.sorted(by: >))
        #expect(!engine.isPlaying)
        #expect(engine.volume == 1)
    }

    @Test func endOfTrackPausesOnTheNextItemInsteadOfAdvancing() async {
        timer.start(.endOfTrack)
        #expect(timer.state == .endOfTrack)

        engine.send(.didFinish(generation: engine.generation))

        #expect(await waitUntil { service.snapshot.currentIndex == 1 })
        #expect(!engine.isPlaying)
        #expect(!service.snapshot.isPlaying)
        #expect(timer.state == .off)
    }

    @Test func withoutTheTimerATrackEndAdvancesAndKeepsPlaying() async {
        engine.send(.didFinish(generation: engine.generation))

        #expect(await waitUntil { service.snapshot.currentIndex == 1 })
        #expect(engine.isPlaying)
    }

    @Test func cancelRestoresTheVolumeAndKeepsPlaying() async {
        timer.start(.minutes(5))
        await settle()
        clock.advance(by: 297)
        #expect(await waitUntil { engine.volume < 0.5 })

        timer.cancel()

        #expect(timer.state == .off)
        #expect(engine.volume == 1)
        #expect(engine.isPlaying)
        clock.advance(by: 10)
        await Task.yield()
        #expect(engine.isPlaying)
    }

    @Test func aUserPauseKeepsTheTimerRunning() {
        timer.start(.minutes(5))

        service.togglePlayPause()

        #expect(timer.state.isActive)
    }

    @Test func playingByHandDuringTheFadeCancelsTheTimer() async {
        timer.start(.minutes(5))
        await settle()
        clock.advance(by: 296)
        #expect(await waitUntil { engine.volume < 0.5 })
        service.togglePlayPause()
        #expect(!engine.isPlaying)

        service.togglePlayPause()

        #expect(timer.state == .off)
        #expect(engine.volume == 1)
        #expect(engine.isPlaying)
    }

    @Test func startingAnotherTimerReplacesTheRunningOne() async {
        timer.start(.minutes(5))
        timer.start(.minutes(60))
        await settle()
        clock.advance(by: 301)
        await Task.yield()

        #expect(engine.isPlaying)
        #expect(timer.state == .countdown(deadline: Date(timeIntervalSince1970: 1000 + 3600)))
    }

    @Test func clearingTheQueueTurnsTheTimerOff() {
        timer.start(.minutes(30))

        service.removeQueueItems(atOffsets: IndexSet(0 ..< tracks.count))

        #expect(timer.state == .off)
    }

    @Test func stoppingAtTheEndOfTheQueueTurnsTheTimerOff() async {
        timer.start(.minutes(30))
        service.jump(toQueueIndex: tracks.count - 1)
        timer.start(.minutes(30))

        engine.send(.didFinish(generation: engine.generation))

        #expect(await waitUntil { timer.state == .off })
    }

    @Test func statesStreamStartsWithTheCurrentState() async {
        timer.start(.endOfTrack)
        var iterator = timer.states().makeAsyncIterator()

        #expect(await iterator.next() == .endOfTrack)
        timer.cancel()
        #expect(await iterator.next() == .off)
    }
}
