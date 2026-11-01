import AVFAudio
import Domain
import Foundation
import Synchronization

/// Receives every buffer the engine renders after the equalizer. Called on an audio thread.
public typealias AudioOutputTap = @Sendable (AVAudioPCMBuffer) -> Void

/// Something that can tap its post-EQ output: `AVAudioPlaybackEngine`, or a fake in tests.
@MainActor
public protocol AudioOutputTapHosting: AnyObject {
    /// Installs `tap` (replacing any previous one), or removes it with nil. The host keeps it installed
    /// across graph rebuilds until it is removed.
    func setOutputTap(_ tap: AudioOutputTap?)
}

/// `AudioSpectrumProviding` over the engine's output tap.
///
/// The first subscriber installs the tap and starts a display loop off the main actor; the last one to
/// cancel removes the tap and stops the loop, so nothing runs while no visualizer is on screen.
/// The loop pops one analysis per frame (30 fps), smooths it and yields to subscribers only when the
/// bars moved; after silence settles it slows to a few checks per second.
@MainActor
public final class AudioSpectrumService: AudioSpectrumProviding {
    public let bandCount: Int
    /// Pause in the analyses (paused playback, a stopped engine) after which the bars fall to rest.
    nonisolated static let silenceAfter: Duration = .milliseconds(150)

    private let host: any AudioOutputTapHosting
    private let subscribers = Subscribers()
    private var loop: Task<Void, Never>?

    public init(host: any AudioOutputTapHosting, bandCount: Int = 28) {
        self.host = host
        self.bandCount = bandCount
    }

    var isRunning: Bool {
        loop != nil
    }

    public func spectrum() -> AsyncStream<[Float]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [Float].self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        subscribers.add(continuation, id: id)
        continuation.onTermination = Self.onTermination(service: self, id: id)
        startIfNeeded()
        return stream
    }

    /// Built in a nonisolated context: `onTermination` is called on whatever thread cancels the stream.
    private nonisolated static func onTermination(
        service: AudioSpectrumService,
        id: UUID
    ) -> @Sendable (AsyncStream<[Float]>.Continuation.Termination) -> Void {
        { [weak service] _ in
            Task { @MainActor in service?.unsubscribe(id) }
        }
    }

    private func unsubscribe(_ id: UUID) {
        guard subscribers.remove(id: id) == 0 else { return }
        host.setOutputTap(nil)
        loop?.cancel()
        loop = nil
    }

    private func startIfNeeded() {
        guard loop == nil else { return }
        let tap = SpectrumTap(bandCount: bandCount)
        host.setOutputTap(Self.makeTap(tap))
        let subscribers = subscribers
        loop = Task.detached(priority: .userInitiated) {
            await Self.run(tap: tap, subscribers: subscribers)
        }
    }

    private nonisolated static func makeTap(_ tap: SpectrumTap) -> AudioOutputTap {
        { buffer in tap.ingest(buffer) }
    }

    private nonisolated static func run(tap: SpectrumTap, subscribers: Subscribers) async {
        let clock = ContinuousClock()
        let frame = Duration.seconds(1 / SpectrumTap.framesPerSecond)
        let idleFrame = Duration.milliseconds(100)
        var smoother = SpectrumSmoother(bandCount: tap.bandCount)
        var targets = [Float](repeating: 0, count: tap.bandCount)
        var lastFrame = clock.now
        var lastTick = clock.now
        var deadline = clock.now
        while !Task.isCancelled {
            let now = clock.now
            if tap.popFrame(into: &targets) {
                lastFrame = now
            } else if lastFrame.duration(to: now) > silenceAfter {
                for index in targets.indices {
                    targets[index] = 0
                }
            }
            let elapsed = lastTick.duration(to: now)
            lastTick = now
            if smoother.step(toward: targets, elapsed: min(elapsed.seconds, 0.1)) {
                subscribers.yield(smoother.values)
            }
            let resting = smoother.isSettled && tap.queuedFrameCount == 0
            deadline = max(deadline + (resting ? idleFrame : frame), now)
            try? await clock.sleep(until: deadline)
        }
    }
}

/// Continuations shared by the main actor (subscribe/unsubscribe) and the display loop (yield).
private final class Subscribers: Sendable {
    private let continuations = Mutex<[UUID: AsyncStream<[Float]>.Continuation]>([:])

    func add(_ continuation: AsyncStream<[Float]>.Continuation, id: UUID) {
        continuations.withLock { $0[id] = continuation }
    }

    /// Returns how many are left.
    func remove(id: UUID) -> Int {
        continuations.withLock {
            $0.removeValue(forKey: id)
            return $0.count
        }
    }

    func yield(_ values: [Float]) {
        let current = continuations.withLock { Array($0.values) }
        for continuation in current {
            continuation.yield(values)
        }
    }
}

private extension Duration {
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
