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

    @Test func rateBypassesTimePitchAtNormalSpeed() {
        #expect(engine.timePitch.bypass)
        engine.setRate(1.5)
        #expect(engine.timePitch.rate == 1.5)
        #expect(!engine.timePitch.bypass)
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
