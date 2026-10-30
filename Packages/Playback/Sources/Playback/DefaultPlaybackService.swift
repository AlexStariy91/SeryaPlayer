import Domain
import Foundation
import os

/// Queue + engine + persisted state. The single player instance used by every feature.
///
/// Play counts: a track is counted (`TrackRepository.markPlayed`) the first time playback actually
/// starts for a loaded file, i.e. once per `load` generation. Restoring a paused queue doesn't count;
/// pressing Play on it does. Repeat One counts every repetition; "Previous" past 3 s (a restart via
/// seek) doesn't.
@MainActor
public final class DefaultPlaybackService: PlaybackControlling {
    public private(set) var snapshot = PlaybackSnapshot() {
        didSet {
            guard snapshot != oldValue else { return }
            for continuation in subscribers.values {
                continuation.yield(snapshot)
            }
        }
    }

    private let engine: any PlaybackEngine
    private let trackRepository: any TrackRepository
    private let stateRepository: any PlaybackStateRepository
    private let nowPlaying: any NowPlayingPublishing
    private let urlForTrack: @Sendable (Track) -> URL
    private let artworkURLForTrack: @Sendable (Track) async -> URL?
    private let now: @Sendable () -> Date
    private var randomGenerator: any RandomNumberGenerator
    private let logger = Logger(subsystem: "com.starodub.SeryaPlayer", category: "PlaybackService")

    private var queue = QueueEngine()
    private var tracksByID: [Track.ID: Track] = [:]
    private var queueTracks: (ids: [Track.ID], tracks: [Track]) = ([], [])
    private var subscribers: [UUID: AsyncStream<PlaybackSnapshot>.Continuation] = [:]
    private var isPlaying = false
    private var rate: Float = 1
    /// Generation returned by the last `engine.load`; `.didFinish` with any other value is stale.
    private var loadedGeneration: Int?
    private var countedGeneration: Int?
    private var resumeAfterInterruption = false
    private var artwork: (trackID: Track.ID, url: URL?)?
    private var artworkTask: Task<Void, Never>?
    private var eventsTask: Task<Void, Never>?

    /// - Parameters:
    ///   - urlForTrack: absolute file URL for a track (resolves `relativePath` against the library root).
    ///   - artworkURLForTrack: large artwork for Now Playing; may return nil.
    ///   - randomGenerator: used for shuffling; inject a seeded generator in tests.
    public init(
        engine: any PlaybackEngine,
        trackRepository: any TrackRepository,
        stateRepository: any PlaybackStateRepository,
        nowPlaying: any NowPlayingPublishing,
        urlForTrack: @escaping @Sendable (Track) -> URL,
        artworkURLForTrack: @escaping @Sendable (Track) async -> URL? = { _ in nil },
        randomGenerator: any RandomNumberGenerator = SystemRandomNumberGenerator(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.engine = engine
        self.trackRepository = trackRepository
        self.stateRepository = stateRepository
        self.nowPlaying = nowPlaying
        self.urlForTrack = urlForTrack
        self.artworkURLForTrack = artworkURLForTrack
        self.randomGenerator = randomGenerator
        self.now = now

        let events = engine.events
        eventsTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    // MARK: - PlaybackControlling

    public var currentTime: TimeInterval {
        engine.currentTime
    }

    public func snapshots() -> AsyncStream<PlaybackSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: PlaybackSnapshot.self, bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        subscribers[id] = continuation
        continuation.yield(snapshot)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.subscribers[id] = nil
            }
        }
        return stream
    }

    public func play(_ tracks: [Track], startingAt index: Int, shuffled: Bool) {
        guard tracks.indices.contains(index) else { return }
        remember(tracks)
        queue.start(with: tracks.map(\.id), at: index, shuffled: shuffled, using: &randomGenerator)
        loadCurrent(at: 0, autoplay: true)
    }

    public func togglePlayPause() {
        if isPlaying {
            engine.pause()
            isPlaying = false
            resumeAfterInterruption = false
            refresh()
            return
        }
        if queue.current == nil {
            guard !queue.items.isEmpty else { return }
            queue.jump(to: 0)
        }
        if loadedGeneration == nil {
            loadCurrent(at: 0, autoplay: true)
        } else {
            startEngine()
        }
    }

    public func next() {
        if queue.advance(userInitiated: true) != nil {
            loadCurrent(at: 0, autoplay: isPlaying)
        } else {
            finishQueue()
        }
    }

    public func previous() {
        let previousIndex = queue.currentIndex
        guard queue.goBack(currentTime: engine.currentTime) != nil, queue.currentIndex != previousIndex else {
            // Past the threshold (or at the very start): restart the current track.
            seek(to: 0)
            return
        }
        loadCurrent(at: 0, autoplay: isPlaying)
    }

    public func seek(to time: TimeInterval) {
        guard loadedGeneration != nil else { return }
        engine.seek(to: time)
        refresh()
    }

    public func toggleShuffle() {
        queue.setShuffle(!queue.isShuffled, using: &randomGenerator)
        refresh()
    }

    public func cycleRepeatMode() {
        queue.repeatMode = switch queue.repeatMode {
        case .off: .all
        case .all: .one
        case .one: .off
        }
        refresh()
    }

    public func playNext(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        remember(tracks)
        let wasIdle = queue.current == nil
        queue.insertNext(tracks.map(\.id))
        startIfIdle(wasIdle)
    }

    public func addToQueue(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        remember(tracks)
        let wasIdle = queue.current == nil
        queue.append(tracks.map(\.id))
        startIfIdle(wasIdle)
    }

    public func moveQueueItems(fromOffsets source: IndexSet, toOffset destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        refresh()
    }

    public func removeQueueItems(atOffsets offsets: IndexSet) {
        let currentBefore = queue.current
        let currentIndexBefore = queue.currentIndex
        queue.remove(atOffsets: offsets)
        if queue.current == nil {
            stopPlayback()
        } else if queue.current != currentBefore || currentIndexBefore.map(offsets.contains) == true {
            loadCurrent(at: 0, autoplay: isPlaying)
        } else {
            refresh()
        }
    }

    public func jump(toQueueIndex index: Int) {
        guard queue.items.indices.contains(index) else { return }
        queue.jump(to: index)
        loadCurrent(at: 0, autoplay: true)
    }

    public func setRate(_ newRate: Float) {
        rate = newRate
        engine.setRate(newRate)
        refresh()
    }

    public func apply(_ equalizer: EQSettings) {
        engine.apply(equalizer)
    }

    public func restore() async {
        guard let saved = await stateRepository.load(), !saved.queue.isEmpty else { return }
        let found: [Track]
        do {
            found = try await trackRepository.tracks(ids: Array(Set(saved.queue + saved.originalQueue)))
        } catch {
            logger.error("Failed to restore the queue: \(error.localizedDescription)")
            return
        }
        // The user may have started something while the tracks were loading.
        guard snapshot.nowPlaying == nil, queue.items.isEmpty else { return }
        remember(found)
        let (state, keptPosition) = Self.dropMissingTracks(from: saved, available: Set(found.map(\.id)))
        guard !state.queue.isEmpty else { return }
        queue = QueueEngine(state: state)
        loadCurrent(at: keptPosition ? state.position : 0, autoplay: false)
    }

    public func persist() async {
        let state = queue.state(position: loadedGeneration == nil ? 0 : engine.currentTime)
        do {
            try await stateRepository.save(state)
        } catch {
            logger.error("Failed to persist the playback state: \(error.localizedDescription)")
        }
    }

    // MARK: - Engine events

    private func handle(_ event: PlaybackEngineEvent) {
        switch event {
        case let .didFinish(generation):
            guard generation == loadedGeneration else { return }
            if queue.advance(userInitiated: false) != nil {
                loadCurrent(at: 0, autoplay: true)
            } else {
                finishQueue()
            }
        case .interruptionBegan:
            resumeAfterInterruption = isPlaying || resumeAfterInterruption
            isPlaying = false
            refresh()
        case let .interruptionEnded(shouldResume):
            let resume = resumeAfterInterruption && shouldResume
            resumeAfterInterruption = false
            if resume {
                startEngine()
            }
        case .routeRequiresPause:
            engine.pause()
            isPlaying = false
            resumeAfterInterruption = false
            refresh()
        case let .failed(message):
            logger.error("Playback failed: \(message)")
            isPlaying = false
            refresh()
        }
    }

    // MARK: - Helpers

    private func remember(_ tracks: [Track]) {
        for track in tracks {
            tracksByID[track.id] = track
        }
    }

    private func startIfIdle(_ wasIdle: Bool) {
        guard wasIdle else {
            refresh()
            return
        }
        if queue.current == nil {
            queue.jump(to: 0)
        }
        loadCurrent(at: 0, autoplay: true)
    }

    /// Loads `queue.current`. A file that fails to load is skipped (once per queue item, so a queue
    /// of broken files ends instead of looping forever).
    private func loadCurrent(at position: TimeInterval, autoplay: Bool) {
        var attempts = 0
        while let id = queue.current, let track = tracksByID[id] {
            do {
                loadedGeneration = try engine.load(url: urlForTrack(track), startingAt: position)
                isPlaying = false
                if autoplay {
                    startEngine()
                } else {
                    refresh()
                }
                return
            } catch {
                logger.error("Failed to load \(track.originalFileName, privacy: .private): \(error.localizedDescription)")
                attempts += 1
                guard attempts < queue.items.count, queue.advance(userInitiated: true) != nil else { break }
            }
        }
        stopPlayback()
    }

    private func startEngine() {
        do {
            try engine.play()
            isPlaying = engine.isPlaying
        } catch {
            logger.error("Failed to start playback: \(error.localizedDescription)")
            isPlaying = false
        }
        if isPlaying, let generation = loadedGeneration, generation != countedGeneration, let id = queue.current {
            countedGeneration = generation
            markPlayed(id)
        }
        refresh()
    }

    private func markPlayed(_ id: Track.ID) {
        let date = now()
        if var track = tracksByID[id] {
            track.playCount += 1
            track.lastPlayedAt = date
            tracksByID[id] = track
        }
        let repository = trackRepository
        Task {
            do {
                try await repository.markPlayed(id: id, at: date)
            } catch {
                Logger(subsystem: "com.starodub.SeryaPlayer", category: "PlaybackService")
                    .error("Failed to mark a track as played: \(error.localizedDescription)")
            }
        }
    }

    /// End of the queue with repeat off: rewind to the first item, paused, like Apple Music.
    private func finishQueue() {
        engine.stop()
        isPlaying = false
        guard !queue.items.isEmpty else {
            stopPlayback()
            return
        }
        queue.jump(to: 0)
        loadCurrent(at: 0, autoplay: false)
    }

    private func stopPlayback() {
        engine.stop()
        isPlaying = false
        loadedGeneration = nil
        refresh()
    }

    /// Recomputes the snapshot and republishes Now Playing.
    private func refresh() {
        if queueTracks.ids != queue.items {
            queueTracks = (queue.items, queue.items.compactMap { tracksByID[$0] })
        }
        let current = loadedGeneration == nil ? nil : queue.current.flatMap { tracksByID[$0] }
        snapshot = PlaybackSnapshot(
            nowPlaying: current,
            isPlaying: isPlaying,
            queue: queueTracks.tracks,
            currentIndex: queue.currentIndex,
            isShuffled: queue.isShuffled,
            repeatMode: queue.repeatMode,
            rate: rate
        )
        publishNowPlaying(for: current)
    }

    private func publishNowPlaying(for track: Track?) {
        guard let track else {
            artworkTask?.cancel()
            artwork = nil
            nowPlaying.clear()
            return
        }
        if artwork?.trackID != track.id {
            artwork = (track.id, nil)
            loadArtwork(for: track)
        }
        nowPlaying.update(NowPlayingInfo(
            title: track.title,
            artist: track.artist,
            album: track.album,
            artworkURL: artwork?.url,
            duration: engine.duration > 0 ? engine.duration : track.duration,
            position: engine.currentTime,
            rate: isPlaying ? rate : 0
        ))
    }

    private func loadArtwork(for track: Track) {
        artworkTask?.cancel()
        let resolve = artworkURLForTrack
        artworkTask = Task { [weak self] in
            let url = await resolve(track)
            guard let self, !Task.isCancelled, let url, self.artwork?.trackID == track.id else { return }
            self.artwork = (track.id, url)
            self.publishNowPlaying(for: track)
        }
    }

    /// Removes tracks deleted since the state was saved and keeps the current item when possible.
    /// Returns the cleaned state and whether the saved position still applies to the current item.
    static func dropMissingTracks(from state: PlaybackState, available: Set<Track.ID>) -> (PlaybackState, keptPosition: Bool) {
        var cleaned = state
        cleaned.queue = state.queue.filter(available.contains)
        cleaned.originalQueue = state.originalQueue.filter(available.contains)
        guard let index = state.currentIndex, state.queue.indices.contains(index), !cleaned.queue.isEmpty else {
            cleaned.currentIndex = cleaned.queue.isEmpty ? nil : 0
            cleaned.position = 0
            return (cleaned, false)
        }
        let survivorsBefore = state.queue[..<index].filter(available.contains).count
        let currentSurvived = available.contains(state.queue[index])
        cleaned.currentIndex = min(survivorsBefore, cleaned.queue.count - 1)
        if !currentSurvived {
            cleaned.position = 0
        }
        return (cleaned, currentSurvived)
    }
}
