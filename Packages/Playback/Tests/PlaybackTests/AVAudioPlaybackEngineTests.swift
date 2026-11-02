import AVFAudio
import Domain
import Foundation
@testable import Playback
import Testing

/// Engine checks that don't need audio output: real files, but nothing is rendered.
@MainActor
struct AVAudioPlaybackEngineTests {
    let engine = AVAudioPlaybackEngine(session: AudioSessionManager())

    @Test func equalizerHasTenBandsWithShelvesAtTheEdges() {
        let bands = engine.equalizer.bands
        #expect(bands.count == EQBands.count)
        #expect(bands.map(\.frequency) == EQBands.frequencies)
        #expect(bands.first?.filterType == .lowShelf)
        #expect(bands.last?.filterType == .highShelf)
        #expect(bands.dropFirst().dropLast().allSatisfy { $0.filterType == .parametric })
        #expect(engine.equalizer.bypass)
    }

    @Test func applyingEqualizerSettingsUpdatesTheUnit() {
        var gains = Array(repeating: Float(0), count: EQBands.count)
        gains[0] = 6
        gains[9] = 20 // out of range: clamped
        engine.apply(EQSettings(isEnabled: true, gains: gains, preamp: -6))

        #expect(!engine.equalizer.bypass)
        #expect(engine.equalizer.globalGain == -6)
        #expect(engine.equalizer.bands[0].gain == 6)
        #expect(engine.equalizer.bands[9].gain == EQBands.gainRange.upperBound)

        engine.apply(EQSettings(isEnabled: false, gains: gains, preamp: -6))
        #expect(engine.equalizer.bypass)
    }

    @Test func timePitchIsInTheChainOnlyAwayFromNormalSpeed() {
        // Even bypassed, the unit delays the signal by ~85 ms.
        #expect(nodeAfterFader(in: engine) === engine.equalizer)
        engine.setRate(1.5)
        #expect(engine.timePitch.rate == 1.5)
        #expect(nodeAfterFader(in: engine) === engine.timePitch)
        engine.setRate(1)
        #expect(nodeAfterFader(in: engine) === engine.equalizer)
    }

    @Test func changingTheRateWhilePlayingKeepsPlayingFromTheSamePlace() async throws {
        try engine.load(url: makeSineFile(seconds: 2, sampleRate: 44100, channels: 2), startingAt: 0.5)
        try engine.play()
        try await Task.sleep(for: .milliseconds(100))
        let before = engine.currentTime

        engine.setRate(1.5)

        #expect(engine.isPlaying)
        #expect(engine.currentTime >= before)
        #expect(nodeAfterFader(in: engine) === engine.timePitch)
        engine.stop()
    }

    // MARK: - Pause and resume fades

    @Test func pauseFadesOutBeforePausingTheNode() async throws {
        let engine = AVAudioPlaybackEngine(session: AudioSessionManager(), pauseFade: .milliseconds(40))
        try engine.load(url: makeSineFile(seconds: 2, sampleRate: 44100, channels: 2), startingAt: 0.5)
        try engine.play()
        try await Task.sleep(for: .milliseconds(100))

        engine.pause()
        #expect(!engine.isPlaying) // reported at once
        #expect(engine.fader.outputVolume > 0) // still fading

        #expect(await eventually { engine.fader.outputVolume == 0 })
        try await Task.sleep(for: .milliseconds(100))
        // The fade was heard, so the resume point is after it.
        #expect(engine.currentTime > 0.6)
        engine.stop()
    }

    @Test func resumeFadesInAndKeepsTheSleepTimerVolume() async throws {
        let engine = AVAudioPlaybackEngine(session: AudioSessionManager(), pauseFade: .milliseconds(40))
        try engine.load(url: makeSineFile(seconds: 2, sampleRate: 44100, channels: 2), startingAt: 0.5)
        engine.setVolume(0.5)
        try engine.play()
        engine.pause()
        #expect(await eventually { engine.fader.outputVolume == 0 })

        try engine.play()
        #expect(engine.fader.outputVolume < 1)
        #expect(await eventually { engine.fader.outputVolume == 1 })
        // The ramp never touches the sleep timer's level.
        #expect(engine.engine.mainMixerNode.outputVolume == 0.5)
        engine.stop()
    }

    @Test func playingDuringTheFadeOutRampsBackWithoutRescheduling() async throws {
        let engine = AVAudioPlaybackEngine(session: AudioSessionManager(), pauseFade: .milliseconds(300))
        try engine.load(url: makeSineFile(seconds: 2, sampleRate: 44100, channels: 2), startingAt: 0.5)
        try engine.play()
        engine.pause()
        try await Task.sleep(for: .milliseconds(50))

        try engine.play()

        #expect(engine.isPlaying)
        #expect(engine.scheduledSegmentCount == 1)
        #expect(await eventually { engine.fader.outputVolume == 1 })
        engine.stop()
    }

    @Test func trackStartIsNotFaded() throws {
        try engine.load(url: makeSineFile(seconds: 1, sampleRate: 44100, channels: 2), startingAt: 0)
        try engine.play()
        #expect(engine.fader.outputVolume == 1)
        engine.stop()
    }

    @Test func pauseWithoutFadingSilencesAtOnce() throws {
        // Used when the headphones are unplugged: a fade would leak to the speaker.
        try engine.load(url: makeSineFile(seconds: 1, sampleRate: 44100, channels: 2), startingAt: 0)
        try engine.play()
        engine.pause(fading: false)
        #expect(engine.fader.outputVolume == 0)
        #expect(!engine.isPlaying)
        engine.stop()
    }

    @Test func seekingDuringTheFadeOutKeepsTheNewPosition() async throws {
        let engine = AVAudioPlaybackEngine(session: AudioSessionManager(), pauseFade: .milliseconds(40))
        try engine.load(url: makeSineFile(seconds: 2, sampleRate: 44100, channels: 2), startingAt: 0)
        try engine.play()
        engine.pause()
        engine.seek(to: 1.5)

        try await Task.sleep(for: .milliseconds(150))

        #expect(engine.currentTime == 1.5)
        engine.stop()
    }

    @Test func loadReportsDurationPositionAndANewGeneration() throws {
        let short = try makeSineFile(seconds: 2, sampleRate: 44100, channels: 2)
        let other = try makeSineFile(seconds: 1, sampleRate: 48000, channels: 1)

        let first = try engine.load(url: short, startingAt: 0.5)
        #expect(abs(engine.duration - 2) < 0.001)
        #expect(engine.currentTime == 0.5)
        #expect(!engine.isPlaying)

        // A different sample rate and channel count reconnects the graph.
        let second = try engine.load(url: other, startingAt: 5)
        #expect(second == first + 1)
        #expect(abs(engine.duration - 1) < 0.001)
        #expect(engine.currentTime == engine.duration) // clamped
    }

    @Test func seekWhilePausedMovesThePosition() throws {
        try engine.load(url: makeSineFile(seconds: 2, sampleRate: 44100, channels: 2), startingAt: 0)

        engine.seek(to: 1.25)
        #expect(engine.currentTime == 1.25)
        engine.seek(to: -1)
        #expect(engine.currentTime == 0)
    }

    @Test func loadingAMissingFileThrows() {
        #expect(throws: (any Error).self) {
            try engine.load(url: URL(fileURLWithPath: "/nonexistent.mp3"), startingAt: 0)
        }
    }

    @Test func playWithoutAFileThrows() {
        #expect(throws: PlaybackEngineError.self) {
            try engine.play()
        }
    }

    @Test func resumingAfterAPauseKeepsTheScheduledSegment() async throws {
        let engine = AVAudioPlaybackEngine(session: AudioSessionManager(), pauseFade: .milliseconds(40))
        try engine.load(url: makeSineFile(seconds: 2, sampleRate: 44100, channels: 2), startingAt: 0.5)
        try engine.play()
        #expect(engine.scheduledSegmentCount == 1)
        try await Task.sleep(for: .milliseconds(200))

        engine.pause()
        let pausedAt = engine.currentTime
        #expect(!engine.isPlaying)
        #expect(pausedAt >= 0.5)
        #expect(await eventually { !engine.engine.isRunning })

        try engine.play()
        // Same segment: the node resumes where it paused instead of reading the file again.
        #expect(engine.isPlaying)
        #expect(engine.scheduledSegmentCount == 1)
        #expect(engine.currentTime >= pausedAt)
        engine.stop()
    }

    @Test func engineIsPausedOnceTheFadeOutEnds() async throws {
        // A running engine, even rendering silence, keeps the app "playing" in Control Center.
        let engine = AVAudioPlaybackEngine(session: AudioSessionManager(), pauseFade: .milliseconds(40))
        try engine.load(url: makeSineFile(seconds: 2, sampleRate: 44100, channels: 2), startingAt: 0.5)
        try engine.play()
        try await Task.sleep(for: .milliseconds(100))

        engine.pause()
        let pausedAt = engine.currentTime
        #expect(engine.engine.isRunning) // still fading

        #expect(await eventually { !engine.engine.isRunning })
        // The position reported at pause already was the final one.
        #expect(engine.currentTime == pausedAt)
        engine.stop()
    }

    @Test func loadingWhilePausedLeavesTheEngineIdle() throws {
        try engine.load(url: makeSineFile(seconds: 1, sampleRate: 44100, channels: 2), startingAt: 0)
        try engine.play()
        engine.pause(fading: false)
        try engine.play()
        engine.pause(fading: false)

        try engine.load(url: makeSineFile(seconds: 1, sampleRate: 44100, channels: 2), startingAt: 0)

        #expect(!engine.engine.isRunning)
        try engine.play()
        #expect(engine.isPlaying)
        engine.stop()
    }

    @Test func seekingWhilePausedSchedulesFromTheNewPosition() throws {
        try engine.load(url: makeSineFile(seconds: 2, sampleRate: 44100, channels: 2), startingAt: 0)
        try engine.play()
        engine.pause()

        engine.seek(to: 1.5)
        try engine.play()

        #expect(engine.scheduledSegmentCount == 2)
        #expect(engine.currentTime >= 1.5)
        engine.stop()
    }

    private func nodeAfterFader(in engine: AVAudioPlaybackEngine) -> AVAudioNode? {
        engine.engine.outputConnectionPoints(for: engine.fader, outputBus: 0).first?.node
    }

    /// Polls for up to a second; the fades run on real time.
    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 200 {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }

    private func makeSineFile(seconds: Double, sampleRate: Double, channels: AVAudioChannelCount) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).caf")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
        let frames = AVAudioFrameCount(seconds * sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for channel in 0 ..< Int(channels) {
            let samples = try #require(buffer.floatChannelData?[channel])
            for frame in 0 ..< Int(frames) {
                samples[frame] = 0.1 * sin(2 * .pi * 440 * Float(frame) / Float(sampleRate))
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
