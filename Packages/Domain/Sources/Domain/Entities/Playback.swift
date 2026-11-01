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

/// Playback speed choices. Pitch is preserved by the engine.
public enum PlaybackRate {
    public static let normal: Float = 1
    public static let options: [Float] = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2]

    /// Nearest allowed speed, for values coming from outside (a remote command, an old setting).
    public static func nearestOption(to rate: Float) -> Float {
        options.min { abs($0 - rate) < abs($1 - rate) } ?? normal
    }
}
