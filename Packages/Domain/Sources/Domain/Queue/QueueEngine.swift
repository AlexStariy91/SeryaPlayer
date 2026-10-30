import Foundation

/// Pure playback queue logic: no timers, audio or storage.
///
/// The contract was fixed in stage 0 so the Playback package can be built in parallel.
/// TODO(stage-1): implementation and tests, see docs/STATUS.md, stage 1.
public struct QueueEngine: Sendable, Equatable {
    public private(set) var items: [Track.ID] = []
    public private(set) var originalOrder: [Track.ID] = []
    public private(set) var currentIndex: Int?
    public private(set) var isShuffled = false
    public var repeatMode: RepeatMode = .off

    /// Threshold for "Previous": after this time the button restarts the current track.
    public static let restartThreshold: TimeInterval = 3

    public init() {}

    public init(state: PlaybackState) {
        items = state.queue
        originalOrder = state.originalQueue
        currentIndex = state.currentIndex
        isShuffled = state.isShuffled
        repeatMode = state.repeatMode
    }

    public var current: Track.ID? {
        currentIndex.flatMap { items.indices.contains($0) ? items[$0] : nil }
    }

    public func state(position: TimeInterval) -> PlaybackState {
        PlaybackState(
            queue: items,
            originalQueue: originalOrder,
            currentIndex: currentIndex,
            position: position,
            isShuffled: isShuffled,
            repeatMode: repeatMode
        )
    }

    /// Sets a new queue. With `shuffled`, the selected track goes first (Fisher–Yates).
    public mutating func start(with _: [Track.ID], at _: Int, shuffled _: Bool, using _: inout some RandomNumberGenerator) {
        fatalError("TODO(stage-1)")
    }

    /// Next track after a natural end (`userInitiated == false`) or a button press.
    /// Returns nil when the queue is over. Repeat one repeats the track only on auto-advance.
    public mutating func advance(userInitiated _: Bool) -> Track.ID? {
        fatalError("TODO(stage-1)")
    }

    /// "Previous": past `restartThreshold`, returns the current track (restart it).
    public mutating func goBack(currentTime _: TimeInterval) -> Track.ID? {
        fatalError("TODO(stage-1)")
    }

    /// Enabling: the current track goes first, the rest are shuffled.
    /// Disabling: restores the original order; the current track stays current.
    public mutating func setShuffle(_: Bool, using _: inout some RandomNumberGenerator) {
        fatalError("TODO(stage-1)")
    }

    public mutating func insertNext(_: [Track.ID]) {
        fatalError("TODO(stage-1)")
    }

    public mutating func append(_: [Track.ID]) {
        fatalError("TODO(stage-1)")
    }

    public mutating func move(fromOffsets _: IndexSet, toOffset _: Int) {
        fatalError("TODO(stage-1)")
    }

    public mutating func remove(atOffsets _: IndexSet) {
        fatalError("TODO(stage-1)")
    }

    public mutating func jump(to _: Int) {
        fatalError("TODO(stage-1)")
    }
}
