import Foundation

public enum RepeatMode: String, CaseIterable, Sendable, Codable {
    case off, all, one
}

/// Persisted player state (a JSON file written when the app goes to background).
public struct PlaybackState: Sendable, Equatable, Codable {
    public var queue: [Track.ID]
    /// Order before shuffling, restored when shuffle is turned off.
    public var originalQueue: [Track.ID]
    public var currentIndex: Int?
    public var position: TimeInterval
    public var isShuffled: Bool
    public var repeatMode: RepeatMode

    public init(
        queue: [Track.ID] = [],
        originalQueue: [Track.ID] = [],
        currentIndex: Int? = nil,
        position: TimeInterval = 0,
        isShuffled: Bool = false,
        repeatMode: RepeatMode = .off
    ) {
        self.queue = queue
        self.originalQueue = originalQueue
        self.currentIndex = currentIndex
        self.position = position
        self.isShuffled = isShuffled
        self.repeatMode = repeatMode
    }
}

/// Snapshot for the UI. Playback time is not included: it is polled via
/// `PlaybackControlling.currentTime` while the player is on screen.
public struct PlaybackSnapshot: Sendable, Equatable {
    public var nowPlaying: Track?
    public var isPlaying: Bool
    public var queue: [Track]
    public var currentIndex: Int?
    public var isShuffled: Bool
    public var repeatMode: RepeatMode
    public var rate: Float

    public init(
        nowPlaying: Track? = nil,
        isPlaying: Bool = false,
        queue: [Track] = [],
        currentIndex: Int? = nil,
        isShuffled: Bool = false,
        repeatMode: RepeatMode = .off,
        rate: Float = 1
    ) {
        self.nowPlaying = nowPlaying
        self.isPlaying = isPlaying
        self.queue = queue
        self.currentIndex = currentIndex
        self.isShuffled = isShuffled
        self.repeatMode = repeatMode
        self.rate = rate
    }
}
