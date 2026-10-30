import Domain
import Foundation
import Observation

/// Playback position, polled from `PlaybackControlling.currentTime` only while `run()` is active
/// (the full player is on screen). Kept apart from `PlayerViewModel` so only the timeline redraws.
@MainActor
@Observable
final class PlaybackProgress {
    private(set) var currentTime: TimeInterval = 0

    @ObservationIgnored private let player: any PlaybackControlling
    @ObservationIgnored private let interval: Duration

    /// 5 Hz: smooth enough for a seconds display, cheap for the main thread.
    init(player: any PlaybackControlling, interval: Duration = .milliseconds(200)) {
        self.player = player
        self.interval = interval
    }

    /// Polls until the calling task is cancelled. Run it from `.task` on the full player.
    func run() async {
        while !Task.isCancelled {
            tick()
            try? await Task.sleep(for: interval)
        }
    }

    /// Reads the player once. Small changes are dropped so a paused player causes no redraws.
    func tick() {
        let time = player.currentTime
        if abs(time - currentTime) >= 0.05 {
            currentTime = time
        }
    }

    /// Seeks and shows the target immediately instead of waiting for the next poll.
    func seek(to time: TimeInterval) {
        player.seek(to: time)
        currentTime = time
    }
}
