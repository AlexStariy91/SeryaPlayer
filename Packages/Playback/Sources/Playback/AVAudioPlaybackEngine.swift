import AVFAudio
import Domain
import Foundation
import os

public enum PlaybackEngineError: Error, Sendable {
    case noFileLoaded
}

/// `AVAudioPlayerNode → AVAudioUnitTimePitch → AVAudioUnitEQ → mainMixerNode`.
///
/// Position model: the file is played as a segment scheduled from `segmentStartFrame`. While playing,
/// the position is the segment start plus the player node's own sample time. Whenever the node is
/// stopped (seek, interruption, configuration change) the position is captured into `resumePosition`
/// and the next `play()` schedules a fresh segment from there.
///
/// Pause is the exception: it pauses only the player node and leaves the engine running (rendering
/// silence), so the scheduled segment and the node's sample time survive and `play()` resumes on the
/// next render cycle. Measured on the output unit, the engine must not be paused for this:
/// `engine.pause()` freezes the I/O together with audio that was already rendered but not yet heard.
/// On restart that tail plays first, the node only joins on the following cycle, and the result is
/// audio → silent gap → audio right after Play (one I/O cycle with `player.pause()`, ~50 ms when the
/// file was rescheduled). After `pausedEngineTimeout` a paused engine is stopped to save power;
/// `engine.stop()` drops the buffered tail, so that resume starts from silence and has no gap either.
///
/// Two counters guard completion callbacks:
/// - `generation` changes on every `load` and is what `.didFinish` reports, so the service can
///   ignore an end-of-file that belongs to a previous track;
/// - `scheduleID` changes on every schedule/stop, so a callback fired by `stop()` during a seek or
///   pause is never reported as a natural end.
@MainActor
public final class AVAudioPlaybackEngine: PlaybackEngine {
    public let events: AsyncStream<PlaybackEngineEvent>
    public private(set) var isPlaying = false

    private let eventsContinuation: AsyncStream<PlaybackEngineEvent>.Continuation
    private let session: AudioSessionManager
    private let center: NotificationCenter
    private let logger = Logger(subsystem: "com.starodub.SeryaPlayer", category: "PlaybackEngine")

    private(set) var engine = AVAudioEngine()
    private(set) var player = AVAudioPlayerNode()
    private(set) var timePitch = AVAudioUnitTimePitch()
    private(set) var equalizer = AVAudioUnitEQ(numberOfBands: EQBands.count)
    private var connectedFormat: AVAudioFormat?
    private var configurationObserver: NotificationObservers?
    /// The visualizer's tap on the main mixer output; re-installed whenever the graph is rebuilt.
    private var outputTap: AudioOutputTap?
    private(set) var isOutputTapInstalled = false

    private var file: AVAudioFile?
    private var generation = 0
    private var scheduleID = 0
    private var segmentStartFrame: AVAudioFramePosition = 0
    private var needsSchedule = true
    /// How long a paused engine keeps rendering silence before it is stopped.
    private let pausedEngineTimeout: Duration
    private var idleStopTask: Task<Void, Never>?
    /// Segments scheduled so far; lets tests check that resuming from a pause doesn't reschedule.
    private(set) var scheduledSegmentCount = 0
    private var resumePosition: TimeInterval = 0
    /// Wall-clock fallback for `currentTime` when the node can't report its time (right after
    /// `play()` or after the engine was stopped behind our back).
    private var playbackAnchor: (position: TimeInterval, instant: ContinuousClock.Instant)?

    private var rate: Float = 1
    private var equalizerSettings = EQSettings()
    private var volume: Float = 1

    /// - Parameter pausedEngineTimeout: a paused engine keeps running this long, so a resume within it
    ///   is seamless; then it is stopped so a paused player doesn't keep the audio hardware (and the
    ///   app, in the background) awake.
    public init(session: AudioSessionManager, center: NotificationCenter = .default, pausedEngineTimeout: Duration = .seconds(30)) {
        self.session = session
        self.center = center
        self.pausedEngineTimeout = pausedEngineTimeout
        (events, eventsContinuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
        do {
            try session.configure()
        } catch {
            logger.error("Failed to configure the audio session: \(error.localizedDescription)")
        }
        session.onEvent = { [weak self] event in self?.handleSessionEvent(event) }
        buildGraph()
    }

    // MARK: - PlaybackEngine

    public var duration: TimeInterval {
        guard let file else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    public var currentTime: TimeInterval {
        guard let file else { return 0 }
        guard isPlaying else { return resumePosition }
        let sampleRate = file.processingFormat.sampleRate
        if let nodeTime = player.lastRenderTime, nodeTime.isSampleTimeValid,
           let playerTime = player.playerTime(forNodeTime: nodeTime) {
            // Right after scheduling, the node reports a slightly negative time until rendering starts.
            let played = Double(max(playerTime.sampleTime, 0)) / playerTime.sampleRate
            let position = Double(segmentStartFrame) / sampleRate + played
            // Right after resuming from a pause, `lastRenderTime` is still the pre-pause one and maps
            // to a time before the resume point until the first new render cycle.
            return clamp(max(position, playbackAnchor?.position ?? 0))
        }
        if let anchor = playbackAnchor {
            let elapsed = anchor.instant.duration(to: .now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            return clamp(anchor.position + seconds * Double(rate))
        }
        return clamp(Double(segmentStartFrame) / sampleRate)
    }

    @discardableResult
    public func load(url: URL, startingAt position: TimeInterval) throws -> Int {
        stopNode()
        let newFile = try AVAudioFile(forReading: url)
        file = newFile
        generation += 1
        isPlaying = false
        playbackAnchor = nil
        needsSchedule = true
        resumePosition = clamp(position)
        scheduleIdleStop()
        if connectedFormat != newFile.processingFormat {
            // Different sample rate or channel count: reconnect the chain with the new format.
            // The engine is stopped first; `play()` starts it again.
            engine.stop()
            connectChain(format: newFile.processingFormat)
        }
        return generation
    }

    public func play() throws {
        guard file != nil else { throw PlaybackEngineError.noFileLoaded }
        try session.activate()
        cancelIdleStop()
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
            needsSchedule = true
        }
        if needsSchedule {
            guard scheduleSegment(from: resumePosition) else {
                // Nothing left to play (the position is at the very end): report the end right away.
                isPlaying = false
                eventsContinuation.yield(.didFinish(generation: generation))
                return
            }
        }
        player.play()
        isPlaying = true
        playbackAnchor = (resumePosition, .now)
    }

    /// Keeps the schedule and the engine running (see the type comment).
    public func pause() {
        guard isPlaying else { return }
        resumePosition = currentTime
        player.pause()
        isPlaying = false
        playbackAnchor = nil
        scheduleIdleStop()
    }

    public func stop() {
        cancelIdleStop()
        stopNode()
        engine.stop()
        isPlaying = false
        resumePosition = 0
        // Let go of the file: it may be about to be deleted. The next `load` opens a new one.
        file = nil
    }

    public func seek(to time: TimeInterval) {
        guard file != nil else { return }
        resumePosition = clamp(time)
        guard isPlaying else {
            needsSchedule = true
            return
        }
        guard scheduleSegment(from: resumePosition) else {
            isPlaying = false
            eventsContinuation.yield(.didFinish(generation: generation))
            return
        }
        player.play()
        playbackAnchor = (resumePosition, .now)
    }

    public func setRate(_ newRate: Float) {
        let position = currentTime
        rate = min(max(newRate, 1 / 32), 32)
        applyRate()
        if isPlaying {
            playbackAnchor = (position, .now)
        }
    }

    public func apply(_ settings: EQSettings) {
        equalizerSettings = settings
        applyEqualizer()
    }

    public func setVolume(_ newVolume: Float) {
        volume = min(max(newVolume, 0), 1)
        applyVolume()
    }

    // MARK: - Graph

    private func buildGraph() {
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        timePitch = AVAudioUnitTimePitch()
        equalizer = AVAudioUnitEQ(numberOfBands: EQBands.count)
        connectedFormat = nil

        for (index, band) in equalizer.bands.enumerated() {
            band.frequency = EQBands.frequencies[index]
            band.filterType = switch index {
            case 0: .lowShelf
            case EQBands.count - 1: .highShelf
            default: .parametric
            }
            band.bandwidth = 1 // octaves; a classic 10-band graphic EQ uses one-octave bands
            band.gain = 0
            band.bypass = false
        }

        engine.attach(player)
        engine.attach(timePitch)
        engine.attach(equalizer)
        connectChain(format: file?.processingFormat)
        applyRate()
        applyEqualizer()
        applyVolume()
        installOutputTap()

        let engineID = ObjectIdentifier(engine)
        let token = center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleConfigurationChange(engineID: engineID)
            }
        }
        configurationObserver = NotificationObservers(center: center, tokens: [token])
    }

    /// `nil` format (nothing loaded yet) lets the engine pick the mixer's format.
    private func connectChain(format: AVAudioFormat?) {
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: equalizer, format: format)
        engine.connect(equalizer, to: engine.mainMixerNode, format: format)
        connectedFormat = format
    }

    /// The main mixer sits after the equalizer and the time-pitch unit, so a fade can't fight either.
    private func applyVolume() {
        engine.mainMixerNode.outputVolume = volume
    }

    private func applyRate() {
        timePitch.rate = rate
        // At 1× the time-pitch unit only adds latency and CPU, so take it out of the signal path.
        timePitch.bypass = rate == 1
    }

    /// Writes only what changed. The EQ is re-applied on every frame of a curve drag, and setting
    /// `bypass` (even to the same value) resets the audio unit, which is heard as dropouts.
    private func applyEqualizer() {
        let settings = equalizerSettings
        for (index, band) in equalizer.bands.enumerated() {
            let gain = settings.gains.indices.contains(index) ? settings.gains[index] : 0
            let clamped = min(max(gain, EQBands.gainRange.lowerBound), EQBands.gainRange.upperBound)
            if band.gain != clamped {
                band.gain = clamped
            }
        }
        if equalizer.globalGain != settings.preamp {
            equalizer.globalGain = settings.preamp
        }
        if equalizer.bypass == settings.isEnabled {
            equalizer.bypass = !settings.isEnabled
        }
    }

    // MARK: - Scheduling

    /// Stops the node and schedules the file from `position`. Returns false if nothing is left to play.
    private func scheduleSegment(from position: TimeInterval) -> Bool {
        stopNode()
        guard let file else { return false }
        let startFrame = min(max(AVAudioFramePosition(position * file.processingFormat.sampleRate), 0), file.length)
        let remaining = file.length - startFrame
        guard remaining > 0 else { return false }
        segmentStartFrame = startFrame
        let frameCount = AVAudioFrameCount(min(remaining, AVAudioFramePosition(AVAudioFrameCount.max)))
        player.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: frameCount,
            at: nil,
            completionCallbackType: .dataPlayedBack,
            completionHandler: Self.completionHandler(engine: self, scheduleID: scheduleID)
        )
        needsSchedule = false
        scheduledSegmentCount += 1
        return true
    }

    /// Stopping the node fires the completion of the scheduled segment; bumping `scheduleID` first
    /// makes that callback stale.
    private func stopNode() {
        scheduleID += 1
        player.stop()
        needsSchedule = true
        playbackAnchor = nil
    }

    // MARK: - Idle engine

    /// Called whenever playback stops while the engine may still be running.
    private func scheduleIdleStop() {
        idleStopTask?.cancel()
        let timeout = pausedEngineTimeout
        idleStopTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.stopIdleEngine()
        }
    }

    private func cancelIdleStop() {
        idleStopTask?.cancel()
        idleStopTask = nil
    }

    /// Stops a paused engine; the next `play()` schedules from `resumePosition` on a fresh start.
    func stopIdleEngine() {
        idleStopTask = nil
        guard !isPlaying, engine.isRunning else { return }
        stopNode()
        engine.stop()
    }

    /// Built in a nonisolated context on purpose: a closure formed inside a `@MainActor` method would
    /// be main-actor isolated, and AVFoundation calls it on its own thread, which traps at runtime.
    private nonisolated static func completionHandler(
        engine: AVAudioPlaybackEngine,
        scheduleID: Int
    ) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { [weak engine] _ in
            Task { @MainActor in
                engine?.segmentDidFinish(scheduleID: scheduleID)
            }
        }
    }

    private func segmentDidFinish(scheduleID finishedID: Int) {
        guard finishedID == scheduleID, isPlaying else { return }
        isPlaying = false
        resumePosition = duration
        needsSchedule = true
        playbackAnchor = nil
        scheduleIdleStop()
        eventsContinuation.yield(.didFinish(generation: generation))
    }

    // MARK: - System events

    private func handleSessionEvent(_ event: AudioSessionManager.Event) {
        switch event {
        case .interruptionBegan:
            // The system already stopped the engine; remember where we were.
            if isPlaying {
                resumePosition = currentTime
                isPlaying = false
            }
            stopNode()
            eventsContinuation.yield(.interruptionBegan)
        case let .interruptionEnded(shouldResume):
            eventsContinuation.yield(.interruptionEnded(shouldResume: shouldResume))
        case .routeRequiresPause:
            // Pause right here so audio never leaks to the speaker while the service catches up.
            pause()
            eventsContinuation.yield(.routeRequiresPause)
        case .mediaServicesReset:
            rebuildAfterMediaServicesReset()
        }
    }

    private func handleConfigurationChange(engineID: ObjectIdentifier) {
        guard engineID == ObjectIdentifier(engine) else { return }
        logger.info("Engine configuration changed")
        let wasPlaying = isPlaying
        resumePosition = currentTime
        isPlaying = false
        stopNode()
        if let format = file?.processingFormat {
            connectChain(format: format)
        }
        // The output format may have changed with the route: tap with the new one.
        removeOutputTapFromGraph()
        installOutputTap()
        guard wasPlaying else { return }
        restartPlayback()
    }

    private func rebuildAfterMediaServicesReset() {
        let wasPlaying = isPlaying
        resumePosition = currentTime
        isPlaying = false
        stopNode()
        configurationObserver = nil
        // The old engine is discarded; `buildGraph` taps the new one.
        isOutputTapInstalled = false
        buildGraph()
        guard wasPlaying else { return }
        restartPlayback()
    }

    private func restartPlayback() {
        do {
            try play()
        } catch {
            logger.error("Failed to restart playback: \(error.localizedDescription)")
            eventsContinuation.yield(.failed(message: error.localizedDescription))
        }
    }

    private func clamp(_ position: TimeInterval) -> TimeInterval {
        min(max(position, 0), duration)
    }
}

// MARK: - Output tap

extension AVAudioPlaybackEngine: AudioOutputTapHosting {
    public func setOutputTap(_ tap: AudioOutputTap?) {
        removeOutputTapFromGraph()
        outputTap = tap
        installOutputTap()
    }

    /// Taps the main mixer: after the time-pitch unit and the equalizer, so EQ changes show.
    private func installOutputTap() {
        guard let outputTap, !isOutputTapInstalled else { return }
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil, block: Self.tapBlock(outputTap))
        isOutputTapInstalled = true
    }

    private func removeOutputTapFromGraph() {
        guard isOutputTapInstalled else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        isOutputTapInstalled = false
    }

    /// Built in a nonisolated context for the same reason as `completionHandler`: the tap block runs
    /// on an audio thread.
    private nonisolated static func tapBlock(_ tap: @escaping AudioOutputTap) -> AVAudioNodeTapBlock {
        { buffer, _ in tap(buffer) }
    }
}
