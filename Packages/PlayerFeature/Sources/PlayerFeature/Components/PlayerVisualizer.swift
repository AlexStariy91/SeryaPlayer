import DesignSystem
import Domain
import SwiftUI

/// Spectrum bars in the artwork's rounded square, mirrored around the middle and tinted with the
/// artwork palette. Subscribes to the spectrum only while the app is active, so the engine tap goes
/// away in the background and on the Lock Screen.
///
/// New levels go straight to Core Animation layers (`SpectrumBarsView`), not into SwiftUI state, so
/// SwiftUI never re-evaluates or re-renders anything per frame.
struct PlayerVisualizer: View {
    let spectrum: any AudioSpectrumProviding
    let colors: [Color]
    let side: CGFloat

    @State private var bars: SpectrumBarsController
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameter levels: what to draw before the first value arrives (previews and snapshots).
    init(spectrum: any AudioSpectrumProviding, colors: [Color], side: CGFloat, levels: [Float] = []) {
        self.spectrum = spectrum
        self.colors = colors
        self.side = side
        _bars = State(initialValue: SpectrumBarsController(
            levels: levels.isEmpty ? Array(repeating: 0, count: spectrum.bandCount) : levels
        ))
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DesignSystem.ArtworkSize.custom(side).cornerRadius, style: .continuous)
        SpectrumBarsView(controller: bars, colors: barColors)
            .padding(side * 0.1)
            .frame(width: side, height: side)
            .background(SemanticColor.fill, in: shape)
            .overlay(shape.strokeBorder(SemanticColor.separator.opacity(0.4), lineWidth: 0.5))
            .task(id: scenePhase == .active) {
                guard scenePhase == .active else { return }
                for await values in spectrum.spectrum() {
                    bars.show(values)
                }
            }
    }

    /// Light tints of the artwork palette (or the accent), so the bars stand out on the darkened
    /// palette background behind the player.
    private var barColors: [Color] {
        let base = colors.isEmpty ? [AccentPalette.serya.color] : Array(colors.prefix(2))
        let edge = base[0].mix(with: .white, by: 0.45)
        let middle = (base.count > 1 ? base[1] : base[0]).mix(with: .white, by: 0.8)
        return [edge, middle, edge]
    }
}

#if DEBUG
    #Preview("Visualizer") {
        PlayerVisualizer(
            spectrum: SilentAudioSpectrum(),
            colors: [.indigo, .pink],
            side: 320,
            levels: PreviewSpectrumLevels.sample
        )
        .padding(40)
        .background { ArtworkBackground(colors: [.indigo, .pink, .orange, .teal]) }
        .environment(\.colorScheme, .dark)
    }
#endif
