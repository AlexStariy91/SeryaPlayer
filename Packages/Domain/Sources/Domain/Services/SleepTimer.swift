import Foundation

/// What the sleep timer is doing right now.
public enum SleepTimerState: Sendable, Equatable {
    case off
    /// Playback fades out and pauses at `deadline`.
    case countdown(deadline: Date)
    /// Playback pauses when the current track ends, instead of advancing.
    case endOfTrack

    public var isActive: Bool {
        self != .off
    }
}

/// What the user can pick in the sleep timer menu.
public enum SleepTimerOption: Sendable, Equatable, Hashable {
    case minutes(Int)
    case endOfTrack

    /// The menu list, in the style of the Clock and Podcasts apps.
    public static let all: [SleepTimerOption] = [.minutes(5), .minutes(15), .minutes(30), .minutes(45), .minutes(60), .endOfTrack]
}

/// Pauses playback after a while or at the end of the track. Not persisted: a relaunch means no timer.
@MainActor
public protocol SleepTimerControlling: AnyObject, Sendable {
    var state: SleepTimerState { get }
    /// A new stream per subscriber; the current state comes first.
    func states() -> AsyncStream<SleepTimerState>
    /// Replaces a running timer.
    func start(_ option: SleepTimerOption)
    /// Turns the timer off and restores the volume if it was fading.
    func cancel()
}
