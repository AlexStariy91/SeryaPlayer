import Domain
import Foundation
import Observation

/// Playback position and speed, polled from `PlaybackControlling.currentTime` only while `run()` is active
/// (the full player is on screen). Kept apart from `PlayerViewModel` so only the timeline redraws.
@MainActor
@Observable
final class PlaybackProgress {
    private(set) var currentTime: TimeInterval = 0
    /// Playback speed, shown next to the position because it changes how fast the remaining time runs out.
    private(set) var rate: Float

    @ObservationIgnored private let player: any PlaybackControlling
    @ObservationIgnored private let interval: Duration
    @ObservationIgnored private let onRateChange: (Float) -> Void

    /// 5 Hz: smooth enough for a seconds display, cheap for the main thread.
    /// - Parameter onRateChange: called after the user picks a speed, to persist it.
    init(player: any PlaybackControlling, interval: Duration = .milliseconds(200), onRateChange: @escaping (Float) -> Void = { _ in }) {
        self.player = player
        self.interval = interval
        self.onRateChange = onRateChange
        rate = player.snapshot.rate
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
        let rate = player.snapshot.rate
        if rate != self.rate {
            self.rate = rate
        }
    }

    /// Seeks and shows the target immediately instead of waiting for the next poll.
    func seek(to time: TimeInterval) {
        player.seek(to: time)
        currentTime = time
    }
}

extension PlaybackProgress {
    /// Changes the speed for every track and shows it immediately.
    func setRate(_ newRate: Float) {
        player.setRate(newRate)
        rate = newRate
        onRateChange(newRate)
    }
}
