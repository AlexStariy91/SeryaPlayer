import Domain
import Foundation

/// Sleep timer for `DefaultPlaybackService`.
///
/// A countdown is a deadline, not a tick count: after every sleep the remaining time is recomputed from
/// `now`, so suspension in the background can't make it drift. During the last `fadeDuration` the engine
/// volume ramps linearly to silence; at the deadline the timer pauses playback, restores the volume
/// (silently, because the engine is already paused) and turns itself off.
@MainActor
public final class SleepTimer: SleepTimerControlling {
    public private(set) var state = SleepTimerState.off {
        didSet {
            guard state != oldValue else { return }
            for continuation in subscribers.values {
                continuation.yield(state)
            }
        }
    }

    /// Set by the service that owns the timer.
    var pausePlayback: @MainActor () -> Void = {}

    private let engine: any PlaybackEngine
    private let fadeDuration: TimeInterval
    private let tick: Duration
    private let now: @Sendable () -> Date
    private let sleep: @MainActor (Duration) async throws -> Void
    private var task: Task<Void, Never>?
    private var isFading = false
    private var subscribers: [UUID: AsyncStream<SleepTimerState>.Continuation] = [:]

    /// - Parameters:
    ///   - now, sleep: the clock; tests inject a fake one. `sleep` is main-actor so it starts counting
    ///     from the moment it is called, not after a hop to another executor.
    public init(
        engine: any PlaybackEngine,
        fadeDuration: TimeInterval = 10,
        tick: Duration = .milliseconds(100),
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.engine = engine
        self.fadeDuration = fadeDuration
        self.tick = tick
        self.now = now
        self.sleep = sleep
    }

    public func states() -> AsyncStream<SleepTimerState> {
        let (stream, continuation) = AsyncStream.makeStream(of: SleepTimerState.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        subscribers[id] = continuation
        continuation.yield(state)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.subscribers[id] = nil
            }
        }
        return stream
    }

    public func start(_ option: SleepTimerOption) {
        cancel()
        switch option {
        case let .minutes(minutes):
            let deadline = now().addingTimeInterval(TimeInterval(minutes) * 60)
            state = .countdown(deadline: deadline)
            task = Task { [weak self] in
                await self?.run(until: deadline)
            }
        case .endOfTrack:
            state = .endOfTrack
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        if isFading {
            isFading = false
            engine.setVolume(1)
        }
        state = .off
    }

    // MARK: - Hooks for the playback service

    /// The current track ended. True if the timer was waiting for it: the service must pause, not advance.
    func trackDidEnd() -> Bool {
        guard state == .endOfTrack else { return false }
        state = .off
        return true
    }

    /// Playback was stopped or the queue was cleared.
    func playbackDidStop() {
        cancel()
    }

    /// The user started playback by hand. During the fade, or after the deadline passed while the countdown
    /// task was not running yet (paused in the background), that means "I'm still awake".
    func userDidStartPlayback() {
        if case let .countdown(deadline) = state, now() >= deadline {
            cancel()
        } else if isFading {
            cancel()
        }
    }

    // MARK: - Countdown

    private func run(until deadline: Date) async {
        while !Task.isCancelled {
            let remaining = deadline.timeIntervalSince(now())
            if remaining <= 0 {
                expire()
                return
            }
            let wait: Duration
            if remaining > fadeDuration {
                wait = .seconds(remaining - fadeDuration)
            } else {
                isFading = true
                engine.setVolume(Float(remaining / fadeDuration))
                wait = min(tick, .seconds(remaining))
            }
            do {
                try await sleep(wait)
            } catch {
                return
            }
        }
    }

    private func expire() {
        task = nil
        pausePlayback()
        if isFading {
            isFading = false
            engine.setVolume(1)
        }
        state = .off
    }
}
