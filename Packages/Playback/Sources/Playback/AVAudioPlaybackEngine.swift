import AVFAudio
import Domain
import Foundation
import os

public enum PlaybackEngineError: Error, Sendable {
    case noFileLoaded
}

/// `AVAudioPlayerNode → fader → AVAudioUnitTimePitch → AVAudioUnitEQ → mainMixerNode`; at 1× the
/// time-pitch unit is left out of the chain. Even bypassed it delays the signal by ~85 ms (measured; it reports a
/// latency of 0), which made every play, pause and seek late and put the resume fade out of step.
///
/// Position model: the file is played as a segment scheduled from `segmentStartFrame`. While playing,
/// the position is the segment start plus the player node's own sample time. Whenever the node is
/// stopped (seek, interruption, configuration change) the position is captured into `resumePosition`
/// and the next `play()` schedules a fresh segment from there.
///
/// Pause is the exception: it fades out, then pauses the player node and the engine, so the scheduled
/// segment and the node's sample time survive and `play()` resumes without reading the file again.
/// The order matters (measured on the output unit): `engine.pause()` freezes the I/O together with
/// audio that was rendered but not yet heard, and plays it on restart before the node joins one cycle
/// later. Paused mid-signal that was heard as audio → silent gap → audio right after Play; paused
/// after the fade the frozen tail is silence, so nothing is heard. The engine must be paused, not left
/// running: iOS shows the app as playing (Control Center, Lock Screen) while its output renders, even
/// silence.
///
/// Pause and resume ramp the fader (a mixer right after the player) over `pauseFade` instead of cutting
/// the waveform mid-cycle, which is heard as a click. It sits before the time-pitch unit so the ramp
/// lines up with the node's own output whatever the unit's delay; the sleep timer's fade (`volume`)
/// stays on the main mixer, so the two compose. `pause()` reports paused at once, at the position the
/// fade will end on; the node is paused when the ramp reaches silence.
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
    private(set) var fader = AVAudioMixerNode()
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
    /// `pause()` paused the engine; the node still holds its schedule.
    private var isEnginePaused = false
    /// Segments scheduled so far; lets tests check that resuming from a pause doesn't reschedule.
    private(set) var scheduledSegmentCount = 0
    /// Engine starts so far; lets tests check that an automatic track change keeps the engine running.
    private(set) var engineStartCount = 0
    /// The pending pause of an engine left idle by `load`; `play()` cancels it.
    private var idlePauseTask: Task<Void, Never>?
    private var resumePosition: TimeInterval = 0
    /// Wall-clock fallback for `currentTime` when the node can't report its time (right after
    /// `play()` or after the engine was stopped behind our back).
    private var playbackAnchor: (position: TimeInterval, instant: ContinuousClock.Instant)?

    private var rate: Float = 1
    private var equalizerSettings = EQSettings()
    private var volume: Float = 1
    private let pauseFade: Duration
    /// The pause/resume ramp, applied by `fader`.
    private lazy var fade = VolumeRamp(
        duration: pauseFade,
        // Weak: a ramp still waiting on the render cycles may outlive the engine.
        apply: { [weak self] gain in self?.fader.outputVolume = gain },
        nodeSampleTime: { [weak self] in self?.nodeSampleTime() },
        renderSampleTime: { [weak self] in self?.engine.mainMixerNode.lastRenderTime?.sampleTime }
    )
    /// `pause()` was called and the fade-out is running; the node still plays until it ends.
    private var isPausePending = false

    /// - Parameter pauseFade: length of the volume ramp on pause and on resume.
    public init(
        session: AudioSessionManager,
        center: NotificationCenter = .default,
        pauseFade: Duration = .milliseconds(80)
    ) {
        self.session = session
        self.center = center
        self.pauseFade = pauseFade
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
        if let position = nodePosition() {
            // Right after resuming from a pause, `lastRenderTime` is still the pre-pause one and maps
            // to a time before the resume point until the first new render cycle.
            return clamp(max(position, playbackAnchor?.position ?? 0))
        }
        if let anchor = playbackAnchor {
            let elapsed = anchor.instant.duration(to: .now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            return clamp(anchor.position + seconds * Double(rate))
        }
        return clamp(Double(segmentStartFrame) / file.processingFormat.sampleRate)
    }

    /// The segment start plus the node's own sample time; nil when the node can't report it.
    private func nodePosition() -> TimeInterval? {
        guard let file, let playerTime = nodePlayerTime() else { return nil }
        // Right after scheduling, the node reports a slightly negative time until rendering starts.
        let played = Double(max(playerTime.sampleTime, 0)) / playerTime.sampleRate
        return clamp(Double(segmentStartFrame) / file.processingFormat.sampleRate + played)
    }

    /// Frames the node has played of the current segment; frozen while it is paused.
    private func nodeSampleTime() -> AVAudioFramePosition? {
        nodePlayerTime()?.sampleTime
    }

    private func nodePlayerTime() -> AVAudioTime? {
        guard let nodeTime = player.lastRenderTime, nodeTime.isSampleTimeValid else { return nil }
        return player.playerTime(forNodeTime: nodeTime)
    }

    @discardableResult
    public func load(url: URL, startingAt position: TimeInterval) throws -> Int {
        if !isPlaying, engine.isRunning {
            // Loaded paused (the end of a track with the "End of Track" sleep timer, a skip while
            // paused): an engine left rendering silence keeps the app "playing" for iOS.
            pauseIdleEngineSoon()
        }
        stopNode()
        let newFile = try AVAudioFile(forReading: url)
        file = newFile
        generation += 1
        isPlaying = false
        playbackAnchor = nil
        needsSchedule = true
        resumePosition = clamp(position)
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
        idlePauseTask?.cancel()
        idlePauseTask = nil
        try session.activate()
        if isPausePending {
            // Play during the fade-out: the node never stopped, so just ramp back up.
            isPausePending = false
            isPlaying = true
            playbackAnchor = (resumePosition, .now)
            fade.ramp(to: 1)
            return
        }
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
            engineStartCount += 1
            // An engine stopped behind our back may have dropped the node's schedule; one paused by
            // `pause()` still has it.
            if !isEnginePaused {
                needsSchedule = true
            }
        }
        isEnginePaused = false
        if needsSchedule {
            guard scheduleSegment(from: resumePosition) else {
                // Nothing left to play (the position is at the very end): report the end right away.
                isPlaying = false
                eventsContinuation.yield(.didFinish(generation: generation))
                return
            }
        }
        // Mid-track the waveform is unlikely to be at zero: fade in. A track start begins at its own level.
        let fadesIn = resumePosition > 0
        fade.set(fadesIn ? 0 : 1)
        let startSample = nodeSampleTime()
        player.play()
        isPlaying = true
        playbackAnchor = (resumePosition, .now)
        if fadesIn {
            // The node starts rendering a while after `play()` (~90 ms measured): ramp from then on,
            // or the ramp is over before the first sample and the click is back.
            fade.ramp(to: 1, afterNodePasses: max(startSample ?? 0, 0))
        }
    }

    /// Fades out, then pauses only the node (see the type comment).
    public func pause() {
        pause(fading: true)
    }

    /// - Parameter fading: false pauses on the spot (the route changed: a fade would leak to the speaker).
    func pause(fading: Bool) {
        if !fading {
            completePendingPause()
        }
        guard isPlaying else { return }
        // Where the node will stop: Now Playing gets the final position once, not one 80 ms short.
        let fadeSeconds = fading ? Double(pauseFade.components.attoseconds) / 1e18 + Double(pauseFade.components.seconds) : 0
        resumePosition = clamp(currentTime + fadeSeconds * Double(rate))
        isPlaying = false
        playbackAnchor = nil
        isPausePending = true
        if fading {
            fade.ramp(to: 0) { [weak self] in self?.completePendingPause() }
        } else {
            completePendingPause()
        }
    }

    /// Pauses the node now if a fade-out is still running; called before anything else touches it.
    private func completePendingPause() {
        guard isPausePending else { return }
        isPausePending = false
        fade.set(0)
        player.pause()
        engine.pause()
        isEnginePaused = true
        logger.notice("Paused after the fade-out; engine running: \(self.engine.isRunning, privacy: .public)")
    }

    public func stop() {
        stopNode()
        engine.stop()
        isPlaying = false
        resumePosition = 0
        // Let go of the file: it may be about to be deleted. The next `load` opens a new one.
        file = nil
    }

    public func seek(to time: TimeInterval) {
        guard file != nil else { return }
        completePendingPause()
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
        let usedTimePitch = usesTimePitch
        rate = min(max(newRate, 1 / 32), 32)
        applyRate()
        guard usesTimePitch != usedTimePitch else {
            if isPlaying {
                playbackAnchor = (position, .now)
            }
            return
        }
        // Into or out of 1×: rewire the chain on a stopped engine and carry on from the same place.
        completePendingPause()
        let wasPlaying = isPlaying
        resumePosition = position
        isPlaying = false
        stopNode()
        engine.stop()
        connectChain(format: connectedFormat)
        if wasPlaying {
            restartPlayback()
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
        fader = AVAudioMixerNode()
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
        engine.attach(fader)
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
        engine.connect(player, to: fader, format: format)
        if usesTimePitch {
            engine.connect(fader, to: timePitch, format: format)
            engine.connect(timePitch, to: equalizer, format: format)
        } else {
            engine.disconnectNodeOutput(timePitch)
            engine.connect(fader, to: equalizer, format: format)
        }
        engine.connect(equalizer, to: engine.mainMixerNode, format: format)
        connectedFormat = format
    }

    /// Only a rate other than 1× needs the time-pitch unit (see the type comment).
    private var usesTimePitch: Bool {
        rate != 1
    }

    /// The main mixer sits after the equalizer and the time-pitch unit, so a fade can't fight either.
    private func applyVolume() {
        engine.mainMixerNode.outputVolume = volume
        fader.outputVolume = fade.gain
    }

    private func applyRate() {
        timePitch.rate = rate
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
        if isPausePending {
            // Stopping anyway: the fade-out has nothing left to protect.
            isPausePending = false
            fade.cancel()
        }
        scheduleID += 1
        player.stop()
        needsSchedule = true
        isEnginePaused = false
        playbackAnchor = nil
    }

    /// Pauses the engine on the next main-actor turn unless `play()` comes first. A track that ends loads the next one
    /// with the engine idle, and the service plays it right away: pausing and restarting the engine there blocked
    /// the main thread on every automatic track change.
    private func pauseIdleEngineSoon() {
        idlePauseTask?.cancel()
        idlePauseTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            idlePauseTask = nil
            guard !isPlaying, !isPausePending, engine.isRunning else { return }
            engine.pause()
        }
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
        guard finishedID == scheduleID else { return }
        if isPausePending {
            // The file ended during the fade-out: stay paused at the end; `play()` reports the finish.
            isPausePending = false
            fade.set(0)
            engine.pause()
            isEnginePaused = true
            resumePosition = duration
            needsSchedule = true
            return
        }
        guard isPlaying else { return }
        isPlaying = false
        resumePosition = duration
        needsSchedule = true
        playbackAnchor = nil
        eventsContinuation.yield(.didFinish(generation: generation))
    }
}

// MARK: - System events

extension AVAudioPlaybackEngine {
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
            pause(fading: false)
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
