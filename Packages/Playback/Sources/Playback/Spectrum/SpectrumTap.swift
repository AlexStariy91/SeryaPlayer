import Accelerate
import AVFAudio
import Foundation
import Synchronization

/// The bridge between the engine's output tap and the display loop.
///
/// The tap delivers audio in large chunks (often ~100 ms on iOS, whatever buffer size is asked for).
/// `ingest` downmixes them into a ring of recent samples and runs one analysis every `hop` samples,
/// queueing the band levels; the display loop pops one analysis per frame, so the bars move at the
/// display rate instead of jumping once per chunk. Every buffer is allocated up front: `ingest` and
/// `popFrame` allocate nothing (except `ingest` after a sample-rate change, which rebuilds the analyzer).
final class SpectrumTap: Sendable {
    /// Analyses per second of audio; the display loop pops at the same rate. 30 rather than 60: with the
    /// smoothing it looks as fluid, and every frame redraws the bars (measured ~17% → ~12% CPU in the simulator).
    static let framesPerSecond = 30.0
    /// Queued analyses beyond this are dropped (oldest first) so the bars never lag the music.
    static let maxQueuedFrames = 8

    let bandCount: Int
    private let state: Mutex<Buffers>

    init(bandCount: Int, sampleRate: Double = 44100, fftSize: Int = 2048) {
        self.bandCount = bandCount
        state = Mutex(Buffers(bandCount: bandCount, sampleRate: sampleRate, fftSize: fftSize))
    }

    /// Called on the tap thread for every rendered buffer. Non-float formats are ignored.
    func ingest(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return }
        let channels = ChannelData(pointer: data)
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        let interleaved = buffer.format.isInterleaved
        state.withLock { buffers in
            if buffers.analyzer.sampleRate != sampleRate {
                buffers.reset(sampleRate: sampleRate)
            }
            var start = 0
            while start < frameCount {
                let count = min(frameCount - start, Buffers.chunkCapacity)
                buffers.downmix(channels.pointer, channelCount: channelCount, interleaved: interleaved, from: start, count: count)
                buffers.appendChunk(count: count)
                start += count
            }
        }
    }

    /// Mono samples straight in; for tests.
    func ingest(mono samples: [Float], sampleRate: Double) {
        state.withLock { buffers in
            if buffers.analyzer.sampleRate != sampleRate {
                buffers.reset(sampleRate: sampleRate)
            }
            samples.withUnsafeBufferPointer { pointer in
                var start = 0
                while start < samples.count {
                    let count = min(samples.count - start, Buffers.chunkCapacity)
                    buffers.load(pointer.baseAddress! + start, count: count)
                    buffers.appendChunk(count: count)
                    start += count
                }
            }
        }
    }

    /// Copies the oldest queued analysis into `bands` (which must hold `bandCount` values).
    /// Returns false when nothing is queued.
    func popFrame(into bands: inout [Float]) -> Bool {
        state.withLock { buffers in
            bands.withUnsafeMutableBufferPointer { buffers.popFrame(into: $0) }
        }
    }

    var queuedFrameCount: Int {
        state.withLock { $0.queuedCount }
    }
}

/// The tap buffer's samples, handed into the mutex for one synchronous `withLock`.
/// `@unchecked Sendable`: the pointer is only read inside that call, while the caller still holds the
/// buffer, and it never escapes into `Buffers`.
private struct ChannelData: @unchecked Sendable {
    let pointer: UnsafePointer<UnsafeMutablePointer<Float>>
}

/// Owned by the tap's mutex.
private final class Buffers {
    let bandCount: Int
    let fftSize: Int
    private(set) var analyzer: SpectrumAnalyzer
    private var hop: Int

    /// The last `fftSize` samples, circular.
    private let ring: UnsafeMutablePointer<Float>
    private var ringIndex = 0
    private var ringFilled = 0
    /// The ring unrolled oldest-first for the analyzer.
    private let window: UnsafeMutablePointer<Float>
    private var samplesSinceFrame = 0

    /// `maxQueuedFrames` × `bandCount` levels, circular.
    private let frames: UnsafeMutablePointer<Float>
    private var frameHead = 0
    private(set) var queuedCount = 0

    init(bandCount: Int, sampleRate: Double, fftSize: Int) {
        self.bandCount = bandCount
        self.fftSize = fftSize
        analyzer = SpectrumAnalyzer(fftSize: fftSize, bandCount: bandCount, sampleRate: sampleRate)
        hop = Self.hop(for: sampleRate)
        ring = .allocate(capacity: fftSize)
        ring.initialize(repeating: 0, count: fftSize)
        window = .allocate(capacity: fftSize)
        chunk = .allocate(capacity: Self.chunkCapacity)
        frames = .allocate(capacity: SpectrumTap.maxQueuedFrames * bandCount)
        frames.initialize(repeating: 0, count: SpectrumTap.maxQueuedFrames * bandCount)
    }

    deinit {
        ring.deallocate()
        window.deallocate()
        chunk.deallocate()
        frames.deallocate()
    }

    private static func hop(for sampleRate: Double) -> Int {
        max(Int(sampleRate / SpectrumTap.framesPerSecond), 1)
    }

    /// After an engine rebuild with another output rate. Allocates (a new analyzer), but only then.
    func reset(sampleRate: Double) {
        analyzer = SpectrumAnalyzer(fftSize: fftSize, bandCount: bandCount, sampleRate: sampleRate)
        hop = Self.hop(for: sampleRate)
        ringIndex = 0
        ringFilled = 0
        samplesSinceFrame = 0
        queuedCount = 0
    }

    /// Mono samples of the current chunk, before they go into the ring.
    static let chunkCapacity = 4096
    private let chunk: UnsafeMutablePointer<Float>

    /// Averages the channels of frames `start ..< start + count` into `chunk` (`count` ≤ `chunkCapacity`).
    func downmix(_ channels: UnsafePointer<UnsafeMutablePointer<Float>>, channelCount: Int, interleaved: Bool, from start: Int, count: Int) {
        let length = vDSP_Length(count)
        let channelCount = max(channelCount, 1)
        if interleaved {
            // One buffer with the channels side by side: add every channelCount-th sample, per channel.
            vDSP_vclr(chunk, 1, length)
            for channel in 0 ..< channelCount {
                vDSP_vadd(channels[0] + start * channelCount + channel, channelCount, chunk, 1, chunk, 1, length)
            }
        } else {
            chunk.update(from: channels[0] + start, count: count)
            for channel in 1 ..< channelCount {
                vDSP_vadd(channels[channel] + start, 1, chunk, 1, chunk, 1, length)
            }
        }
        var scale = 1 / Float(channelCount)
        vDSP_vsmul(chunk, 1, &scale, chunk, 1, length)
    }

    /// Copies mono samples into `chunk` (`count` ≤ `chunkCapacity`).
    func load(_ samples: UnsafePointer<Float>, count: Int) {
        chunk.update(from: samples, count: count)
    }

    /// Moves the first `count` samples of `chunk` into the ring, analysing every `hop` samples.
    func appendChunk(count: Int) {
        var offset = 0
        while offset < count {
            let take = min(count - offset, hop - samplesSinceFrame, fftSize - ringIndex)
            (ring + ringIndex).update(from: chunk + offset, count: take)
            ringIndex = (ringIndex + take) % fftSize
            ringFilled = min(ringFilled + take, fftSize)
            samplesSinceFrame += take
            offset += take
            if samplesSinceFrame >= hop {
                samplesSinceFrame = 0
                if ringFilled == fftSize {
                    analyzeRing()
                }
            }
        }
    }

    private func analyzeRing() {
        // Oldest sample first: ring[ringIndex...] then ring[..<ringIndex].
        let tail = fftSize - ringIndex
        window.update(from: ring + ringIndex, count: tail)
        (window + tail).update(from: ring, count: ringIndex)
        if queuedCount == SpectrumTap.maxQueuedFrames {
            frameHead = (frameHead + 1) % SpectrumTap.maxQueuedFrames
            queuedCount -= 1
        }
        let slot = (frameHead + queuedCount) % SpectrumTap.maxQueuedFrames
        analyzer.analyze(window, into: frames + slot * bandCount)
        queuedCount += 1
    }

    func popFrame(into bands: UnsafeMutableBufferPointer<Float>) -> Bool {
        guard queuedCount > 0, let base = bands.baseAddress else { return false }
        base.update(from: frames + frameHead * bandCount, count: min(bands.count, bandCount))
        frameHead = (frameHead + 1) % SpectrumTap.maxQueuedFrames
        queuedCount -= 1
        return true
    }
}
