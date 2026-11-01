import AVFAudio
import Domain
import DomainTestSupport
import Foundation
@testable import Playback
import Testing

struct SpectrumAnalyzerTests {
    let analyzer = SpectrumAnalyzer(fftSize: 2048, bandCount: 28, sampleRate: 44100)

    /// Analyses the same window for 3 s of 30 fps frames, so the automatic gain settles, and returns the last.
    private func analyze(_ samples: [Float]) -> [Float] {
        var bands = [Float](repeating: -1, count: analyzer.bandCount)
        for _ in 0 ..< 90 {
            samples.withUnsafeBufferPointer { input in
                bands.withUnsafeMutableBufferPointer { output in
                    analyzer.analyze(input.baseAddress!, into: output.baseAddress!, elapsed: 1.0 / 30)
                }
            }
        }
        return bands
    }

    private func sine(_ frequency: Double, amplitude: Float = 0.5, sampleRate: Double = 44100) -> [Float] {
        (0 ..< 2048).map { amplitude * Float(sin(2 * .pi * frequency * Double($0) / sampleRate)) }
    }

    @Test(arguments: [60.0, 250, 1000, 4000, 12000])
    func sineLandsInItsBand(frequency: Double) throws {
        let bands = analyze(sine(frequency))
        let expected = try #require(analyzer.band(containing: frequency))
        let loudest = try #require(bands.indices.max { bands[$0] < bands[$1] })

        #expect(loudest == expected)
        #expect(bands[loudest] > 0.5)
        // Far from the tone there is (almost) nothing: only the window's side lobes.
        #expect(bands.enumerated().filter { abs($0.offset - expected) > 5 }.allSatisfy { $0.element < 0.15 })
    }

    @Test func silenceGivesZeros() {
        #expect(analyze([Float](repeating: 0, count: 2048)) == [Float](repeating: 0, count: 28))
    }

    @Test func levelsStayInRange() {
        let loud = (0 ..< 2048).map { _ in Float.random(in: -1 ... 1) }
        #expect(analyze(loud).allSatisfy { (0 ... 1).contains($0) })
    }

    @Test func bandsAreLogSpacedAndCoverEveryBinOnce() {
        let ranges = SpectrumAnalyzer.bandRanges(bandCount: 28, fftSize: 2048, sampleRate: 44100)
        #expect(ranges.count == 28)
        #expect(ranges.allSatisfy { !$0.bins.isEmpty })
        for (lower, upper) in zip(ranges, ranges.dropFirst()) {
            #expect(upper.center > lower.center * 1.2)
            #expect(upper.bins.lowerBound >= lower.bins.lowerBound)
        }
        // Each band of the upper half is wider than the one before it.
        let upperHalf = ranges.suffix(14).map(\.bins.count)
        #expect(zip(upperHalf, upperHalf.dropFirst()).allSatisfy { $0 <= $1 })
    }
}

/// Calibration on signals closer to real music than sines, through the whole tap (ring, hop, gain).
struct SpectrumCalibrationTests {
    static let sampleRate = 44100.0

    /// Pink noise (Paul Kellet's filter on seeded white noise), roughly -12 dBFS RMS before `gain`.
    static func pinkNoise(seconds: Double, gain: Float, seed: UInt64 = 7) -> [Float] {
        var generator = SeededGenerator(seed: seed)
        var b0: Float = 0, b1: Float = 0, b2: Float = 0
        return (0 ..< Int(seconds * sampleRate)).map { _ in
            let white = Float.random(in: -1 ... 1, using: &generator)
            b0 = 0.99765 * b0 + white * 0.0990460
            b1 = 0.96300 * b1 + white * 0.2965164
            b2 = 0.57000 * b2 + white * 1.0526913
            return (b0 + b1 + b2 + white * 0.1848) * 0.12 * gain
        }
    }

    /// A loud, soft-clipped chord with bass, mids and treble partials, like a loudly mastered track.
    static func compressedMultiTone(seconds: Double, gain: Float) -> [Float] {
        let partials: [(frequency: Double, amplitude: Double)] = [
            (55, 1), (110, 0.8), (220, 0.6), (330, 0.5), (440, 0.5), (660, 0.4), (880, 0.35),
            (1320, 0.3), (1760, 0.25), (2640, 0.2), (3520, 0.16), (5280, 0.12), (7040, 0.1), (10560, 0.07),
        ]
        return (0 ..< Int(seconds * sampleRate)).map { frame in
            let time = Double(frame) / sampleRate
            let sum = partials.reduce(0) { $0 + $1.amplitude * sin(2 * .pi * $1.frequency * time) }
            return Float(tanh(sum * 0.9)) * gain
        }
    }

    /// Feeds `samples` through a fresh tap and returns every queued analysis left at the end (up to 8).
    private func levels(after samples: [Float], tap: SpectrumTap = SpectrumTap(bandCount: 28)) -> [[Float]] {
        tap.ingest(mono: samples, sampleRate: Self.sampleRate)
        var frames: [[Float]] = []
        var bands = [Float](repeating: 0, count: 28)
        while tap.popFrame(into: &bands) {
            frames.append(bands)
        }
        return frames
    }

    private func checkLively(_ frames: [[Float]]) {
        let all = frames.flatMap(\.self)
        let loudest = all.max() ?? 0
        let pinned = Double(all.filter { $0 >= 0.99 }.count) / Double(all.count)
        let mean = all.reduce(0, +) / Float(all.count)
        #expect(loudest > 0.6, "peaks use most of the height")
        #expect(pinned < 0.1, "bars are not stuck at the ceiling: \(pinned)")
        #expect((0.2 ... 0.75).contains(mean), "mean level \(mean)")
        // Bands differ: not a wall of equal bars, and neither end of the spectrum is dead.
        for bands in frames {
            let spread = (bands.max() ?? 0) - (bands.min() ?? 0)
            #expect(spread > 0.25)
            #expect(bands.prefix(6).reduce(0, +) / 6 > 0.1, "lows")
            #expect(bands.suffix(6).reduce(0, +) / 6 > 0.1, "highs")
        }
    }

    @Test func loudPinkNoiseIsLively() {
        checkLively(levels(after: Self.pinkNoise(seconds: 4, gain: 1)))
    }

    @Test func quietPinkNoiseUsesTheRangeToo() {
        checkLively(levels(after: Self.pinkNoise(seconds: 6, gain: 0.1)))
    }

    @Test func loudCompressedMixIsNotPinned() {
        let frames = levels(after: Self.compressedMultiTone(seconds: 4, gain: 1))
        let all = frames.flatMap(\.self)
        #expect((all.max() ?? 0) > 0.6)
        #expect(Double(all.filter { $0 >= 0.99 }.count) / Double(all.count) < 0.1)
    }

    @Test func quietCompressedMixUsesTheRange() {
        let frames = levels(after: Self.compressedMultiTone(seconds: 6, gain: 0.1))
        let all = frames.flatMap(\.self)
        #expect((all.max() ?? 0) > 0.6)
        #expect(Double(all.filter { $0 >= 0.99 }.count) / Double(all.count) < 0.1)
    }

    @Test func silenceStaysAtZero() {
        let frames = levels(after: [Float](repeating: 0, count: Int(2 * Self.sampleRate)))
        #expect(!frames.isEmpty)
        #expect(frames.allSatisfy { $0.allSatisfy { $0 == 0 } })
    }

    @Test func nearSilenceIsNotAmplified() {
        let frames = levels(after: Self.pinkNoise(seconds: 6, gain: 0.0005))
        #expect(frames.flatMap(\.self).allSatisfy { $0 < 0.3 })
    }

    @Test func transientAfterAQuietPartReachesTheTop() {
        let tap = SpectrumTap(bandCount: 28)
        _ = levels(after: Self.pinkNoise(seconds: 5, gain: 0.03), tap: tap)
        // 1/15 s of a loud hit: the first analyses that contain it.
        let hit = Self.pinkNoise(seconds: 1.0 / 15, gain: 1, seed: 11)
        let frames = levels(after: hit, tap: tap)
        #expect((frames.flatMap(\.self).max() ?? 0) > 0.95)
    }
}

struct SpectrumSmootherTests {
    @Test func risesFasterThanItFalls() {
        var rising = SpectrumSmoother(bandCount: 1)
        rising.step(toward: [1], elapsed: 1 / 60)

        var falling = SpectrumSmoother(bandCount: 1)
        for _ in 0 ..< 200 {
            falling.step(toward: [1], elapsed: 1 / 60)
        }
        falling.step(toward: [0], elapsed: 1 / 60)

        #expect(rising.values[0] > 0.3)
        #expect(1 - falling.values[0] < 0.15)
        #expect(rising.values[0] > 1 - falling.values[0])
    }

    @Test func settlesToZeroInSilence() {
        var smoother = SpectrumSmoother(bandCount: 3)
        smoother.step(toward: [1, 0.5, 0.2], elapsed: 0.1)
        #expect(!smoother.isSettled)

        var moved = true
        for _ in 0 ..< 120 where moved {
            moved = smoother.step(toward: [], elapsed: 1 / 60)
        }

        #expect(smoother.isSettled)
        #expect(smoother.values == [0, 0, 0])
        let movedAgain = smoother.step(toward: [0, 0, 0], elapsed: 1 / 60)
        #expect(!movedAgain)
    }
}

struct SpectrumTapTests {
    @Test func queuesOneAnalysisPerHop() {
        let tap = SpectrumTap(bandCount: 28, sampleRate: 44100)
        let samples = (0 ..< 44100 / 10).map { 0.5 * Float(sin(2 * .pi * 1000 * Double($0) / 44100)) }

        tap.ingest(mono: samples, sampleRate: 44100)

        // 4410 samples, one analysis per 1470 once a full 2048-sample window is in: at 2940 and 4410.
        #expect(tap.queuedFrameCount == 2)
        var bands = [Float](repeating: 0, count: 28)
        let popped = tap.popFrame(into: &bands)
        #expect(popped)
        #expect(bands.contains { $0 > 0.5 })
        #expect(tap.queuedFrameCount == 1)
    }

    @Test func downmixesInterleavedBuffers() throws {
        let tap = SpectrumTap(bandCount: 28, sampleRate: 44100)
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: true))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410))
        buffer.frameLength = 4410
        let data = try #require(buffer.floatChannelData?[0])
        for frame in 0 ..< 4410 {
            let sample = 0.5 * Float(sin(2 * .pi * 1000 * Double(frame) / 44100))
            data[frame * 2] = sample
            data[frame * 2 + 1] = sample
        }

        tap.ingest(buffer)

        var bands = [Float](repeating: 0, count: 28)
        let popped = tap.popFrame(into: &bands)
        #expect(popped)
        let analyzer = SpectrumAnalyzer(bandCount: 28, sampleRate: 44100)
        let loudest = bands.indices.max { bands[$0] < bands[$1] }
        #expect(loudest == analyzer.band(containing: 1000))
    }

    @Test func dropsTheOldestAnalysesWhenNobodyReads() {
        let tap = SpectrumTap(bandCount: 28, sampleRate: 44100)
        tap.ingest(mono: [Float](repeating: 0.1, count: 44100), sampleRate: 44100)
        #expect(tap.queuedFrameCount == SpectrumTap.maxQueuedFrames)
    }

    @Test func downmixesPCMBuffers() throws {
        let tap = SpectrumTap(bandCount: 28, sampleRate: 48000)
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4800))
        buffer.frameLength = 4800
        for channel in 0 ..< 2 {
            let data = try #require(buffer.floatChannelData?[channel])
            for frame in 0 ..< 4800 {
                data[frame] = 0.5 * Float(sin(2 * .pi * 500 * Double(frame) / 48000))
            }
        }

        tap.ingest(buffer)

        #expect(tap.queuedFrameCount > 0)
    }
}

@MainActor
final class FakeTapHost: AudioOutputTapHosting {
    private(set) var tap: AudioOutputTap?
    private(set) var changes = 0

    func setOutputTap(_ tap: AudioOutputTap?) {
        self.tap = tap
        changes += 1
    }
}

@MainActor
struct AudioSpectrumServiceTests {
    @Test func tapIsInstalledOnlyWhileSubscribed() async throws {
        let host = FakeTapHost()
        let service = AudioSpectrumService(host: host, bandCount: 28)
        #expect(host.tap == nil)

        let first = Task { for await _ in service.spectrum() {} }
        let second = Task { for await _ in service.spectrum() {} }
        #expect(await waitUntil { host.tap != nil })
        #expect(host.changes == 1)
        #expect(service.isRunning)

        first.cancel()
        try await Task.sleep(for: .milliseconds(50))
        #expect(host.tap != nil)

        second.cancel()
        #expect(await waitUntil { host.tap == nil })
        #expect(!service.isRunning)
    }

    @Test func publishesBandsFromTheTappedAudio() async throws {
        let host = FakeTapHost()
        let service = AudioSpectrumService(host: host, bandCount: 28)
        let stream = service.spectrum()
        let tap = try #require(host.tap)

        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410))
        buffer.frameLength = 4410
        let data = try #require(buffer.floatChannelData?[0])
        for frame in 0 ..< 4410 {
            data[frame] = 0.5 * Float(sin(2 * .pi * 1000 * Double(frame) / 44100))
        }
        tap(buffer)

        var latest: [Float] = []
        for await bands in stream {
            latest = bands
            if bands.contains(where: { $0 > 0.3 }) {
                break
            }
        }
        #expect(latest.count == 28)
        #expect(latest.contains { $0 > 0.3 })
    }

    @Test func engineKeepsTheTapAcrossOutputChanges() {
        let engine = AVAudioPlaybackEngine(session: AudioSessionManager())
        #expect(!engine.isOutputTapInstalled)

        engine.setOutputTap { _ in }
        #expect(engine.isOutputTapInstalled)
        // Replacing it must not install a second tap on the bus (that raises an exception).
        engine.setOutputTap { _ in }
        #expect(engine.isOutputTapInstalled)

        engine.setOutputTap(nil)
        #expect(!engine.isOutputTapInstalled)
    }
}

@MainActor
private func waitUntil(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0 ..< 200 {
        if condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}
