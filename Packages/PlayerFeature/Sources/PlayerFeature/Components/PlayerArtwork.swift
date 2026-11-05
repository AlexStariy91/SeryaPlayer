import DesignSystem
import Domain
import SwiftUI

/// Full-player artwork, or the spectrum visualizer in its place: tapping toggles between them with a
/// short crossfade. Shrinks with a spring while paused, like Apple Music.
struct PlayerArtwork: View {
    let url: URL?
    let isPlaying: Bool
    let side: CGFloat
    var showsVisualizer = false
    var spectrum: any AudioSpectrumProviding = SilentAudioSpectrum()
    var colors: [Color] = []
    var onToggle: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if showsVisualizer {
                PlayerVisualizer(spectrum: spectrum, colors: colors, side: side)
                    .transition(.opacity)
            } else {
                ArtworkView(url: url, size: .custom(side), placeholderStyle: .prominent)
                    .shadow(color: .black.opacity(isPlaying ? 0.35 : 0.15), radius: isPlaying ? 24 : 10, y: isPlaying ? 12 : 4)
                    .transition(.opacity)
            }
        }
        .frame(width: side, height: side)
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.ArtworkSize.custom(side).cornerRadius, style: .continuous))
        .onTapGesture(perform: onToggle)
        .animation(.easeInOut(duration: 0.3), value: showsVisualizer)
        .scaleEffect(isPlaying ? 1 : 0.8)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.68), value: isPlaying)
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsVisualizer ? Text("Visualizer", bundle: .module) : Text("Artwork", bundle: .module))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onToggle() }
        .accessibilityHint(showsVisualizer ? Text("Shows the artwork.", bundle: .module) : Text("Shows the visualizer.", bundle: .module))
    }
}
