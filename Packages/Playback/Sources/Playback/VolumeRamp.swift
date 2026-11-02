import AVFAudio
import Foundation

/// The pause/resume fade of `AVAudioPlaybackEngine`. Moves a gain linearly over `duration` on the main
/// actor, a step every few milliseconds; the mixer it drives smooths each step across a render cycle
/// (measured: no step between neighbouring output samples).
@MainActor
final class VolumeRamp {
    private(set) var gain: Float = 1

    private let duration: Duration
    private let apply: @MainActor (Float) -> Void
    private let nodeSampleTime: @MainActor () -> AVAudioFramePosition?
    private let renderSampleTime: @MainActor () -> AVAudioFramePosition?
    private var task: Task<Void, Never>?

    private static let step = Duration.milliseconds(4)
    private static let maxStartWait = Duration.milliseconds(500)

    /// - Parameters:
    ///   - apply: writes the gain to the mixer.
    ///   - nodeSampleTime: the player node's sample time; frozen while it is paused.
    ///   - renderSampleTime: the mixer's last render time; advances once per render cycle.
    init(
        duration: Duration,
        apply: @escaping @MainActor (Float) -> Void,
        nodeSampleTime: @escaping @MainActor () -> AVAudioFramePosition?,
        renderSampleTime: @escaping @MainActor () -> AVAudioFramePosition?
    ) {
        self.duration = duration
        self.apply = apply
        self.nodeSampleTime = nodeSampleTime
        self.renderSampleTime = renderSampleTime
    }

    /// Jumps to `value`, cancelling a running ramp.
    func set(_ value: Float) {
        cancel()
        gain = value
        apply(value)
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Ramps to `target`. With `startSample`, waits (up to `maxStartWait`) until the node renders past
    /// that sample time: the node starts a while after `play()`, and a ramp that is over before its first
    /// sample is no ramp at all. `completion` runs only if the ramp wasn't cancelled, two render cycles
    /// after the last step so the mixer has applied it.
    func ramp(
        to target: Float,
        afterNodePasses startSample: AVAudioFramePosition? = nil,
        then completion: (@MainActor () -> Void)? = nil
    ) {
        cancel()
        task = Task { [weak self] in
            await self?.run(to: target, afterNodePasses: startSample)
            guard let self, !Task.isCancelled else { return }
            task = nil
            completion?()
        }
    }

    private func run(to target: Float, afterNodePasses startSample: AVAudioFramePosition?) async {
        let clock = ContinuousClock()
        if let startSample {
            let deadline = clock.now.advanced(by: Self.maxStartWait)
            while clock.now < deadline, !Task.isCancelled {
                if let sample = nodeSampleTime(), sample > startSample {
                    break
                }
                try? await Task.sleep(for: .milliseconds(2))
            }
        }
        let start = gain
        let begin = clock.now
        while !Task.isCancelled {
            let progress = duration > .zero ? min(begin.duration(to: clock.now) / duration, 1) : 1
            gain = start + (target - start) * Float(progress)
            apply(gain)
            if progress >= 1 {
                break
            }
            try? await Task.sleep(for: Self.step)
        }
        // Pausing the node right after the last step cut the tail of the fade (a step of about a tenth of
        // the level, measured): let the mixer render it first.
        await waitForRenderCycles(2)
    }

    private func waitForRenderCycles(_ count: Int) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(300))
        var last = renderSampleTime()
        var seen = 0
        while seen < count, clock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(2))
            let current = renderSampleTime()
            if current != last {
                seen += 1
                last = current
            }
        }
    }
}
