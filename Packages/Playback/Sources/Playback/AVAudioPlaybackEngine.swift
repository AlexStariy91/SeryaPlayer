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
/// stopped (pause, seek, interruption, configuration change) the position is captured into
/// `resumePosition` and the next `play()` schedules a fresh segment from there.
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

    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private(set) var timePitch = AVAudioUnitTimePitch()
    private(set) var equalizer = AVAudioUnitEQ(numberOfBands: EQBands.count)
    private var connectedFormat: AVAudioFormat?
    private var configurationObserver: NotificationObservers?

    private var file: AVAudioFile?
    private var generation = 0
    private var scheduleID = 0
    private var segmentStartFrame: AVAudioFramePosition = 0
    private var needsSchedule = true
    private var resumePosition: TimeInterval = 0
    /// Wall-clock fallback for `currentTime` when the node can't report its time (right after
    /// `play()` or after the engine was stopped behind our back).
    private var playbackAnchor: (position: TimeInterval, instant: ContinuousClock.Instant)?

    private var rate: Float = 1
    private var equalizerSettings = EQSettings()

    public init(session: AudioSessionManager, center: NotificationCenter = .default) {
        self.session = session
        self.center = center
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
            return clamp(position)
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

    public func pause() {
        guard isPlaying else { return }
        resumePosition = currentTime
        stopNode()
        engine.pause()
        isPlaying = false
    }

    public func stop() {
        stopNode()
        engine.stop()
        isPlaying = false
        resumePosition = 0
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

    private func applyRate() {
        timePitch.rate = rate
        // At 1× the time-pitch unit only adds latency and CPU, so take it out of the signal path.
        timePitch.bypass = rate == 1
    }

    private func applyEqualizer() {
        let settings = equalizerSettings
        for (index, band) in equalizer.bands.enumerated() {
            let gain = settings.gains.indices.contains(index) ? settings.gains[index] : 0
            band.gain = min(max(gain, EQBands.gainRange.lowerBound), EQBands.gainRange.upperBound)
        }
        equalizer.globalGain = settings.preamp
        equalizer.bypass = !settings.isEnabled
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
        guard wasPlaying else { return }
        restartPlayback()
    }

    private func rebuildAfterMediaServicesReset() {
        let wasPlaying = isPlaying
        resumePosition = currentTime
        isPlaying = false
        stopNode()
        configurationObserver = nil
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
