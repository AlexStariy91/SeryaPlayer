import DesignSystem
import SwiftUI

/// The only view that reads `PlaybackProgress`, so polling redraws nothing else.
struct PlayerTimeline: View {
    let progress: PlaybackProgress
    let duration: TimeInterval

    var body: some View {
        TimelineSlider(current: progress.currentTime, duration: duration) { time in
            progress.seek(to: time)
        }
        .tint(.white)
    }
}
