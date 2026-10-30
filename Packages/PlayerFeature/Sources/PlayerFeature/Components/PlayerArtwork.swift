import DesignSystem
import SwiftUI

/// Full-player artwork. Shrinks with a spring while paused, like Apple Music.
struct PlayerArtwork: View {
    let url: URL?
    let isPlaying: Bool
    let side: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ArtworkView(url: url, size: .custom(side))
            .shadow(color: .black.opacity(isPlaying ? 0.35 : 0.15), radius: isPlaying ? 24 : 10, y: isPlaying ? 12 : 4)
            .scaleEffect(isPlaying ? 1 : 0.8)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.68), value: isPlaying)
            .frame(width: side, height: side)
    }
}
