import DesignSystem
import Domain
import SwiftUI

/// Spectrum bars in the artwork's rounded square, mirrored around the middle and tinted with the
/// artwork palette. Subscribes to the spectrum only while the app is active, so the engine tap goes
/// away in the background and on the Lock Screen; the levels are this view's own state, so a new
/// frame redraws only the bars, never the rest of the player.
struct PlayerVisualizer: View {
    let spectrum: any AudioSpectrumProviding
    let colors: [Color]
    let side: CGFloat

    @State private var levels: [Float]
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameter levels: what to draw before the first value arrives (previews and snapshots).
    init(spectrum: any AudioSpectrumProviding, colors: [Color], side: CGFloat, levels: [Float] = []) {
        self.spectrum = spectrum
        self.colors = colors
        self.side = side
        _levels = State(initialValue: levels.isEmpty ? Array(repeating: 0, count: spectrum.bandCount) : levels)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DesignSystem.ArtworkSize.custom(side).cornerRadius, style: .continuous)
        SpectrumBars(levels: levels, colors: barColors)
            .padding(side * 0.1)
            .drawingGroup()
            .frame(width: side, height: side)
            .background(SemanticColor.fill, in: shape)
            .overlay(shape.strokeBorder(SemanticColor.separator.opacity(0.4), lineWidth: 0.5))
            .task(id: scenePhase == .active) {
                guard scenePhase == .active else { return }
                for await values in spectrum.spectrum() {
                    levels = values
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

/// The bars themselves, drawn in one `Canvas` pass.
private struct SpectrumBars: View {
    let levels: [Float]
    let colors: [Color]

    var body: some View {
        Canvas { context, size in
            guard !levels.isEmpty else { return }
            let count = CGFloat(levels.count)
            let pitch = size.width / count
            let width = pitch * 0.62
            var bars = Path()
            for (index, level) in levels.enumerated() {
                // A level of 0 leaves a round dot: the resting state while paused.
                let height = max(width, CGFloat(min(max(level, 0), 1)) * size.height)
                let rect = CGRect(
                    x: CGFloat(index) * pitch + (pitch - width) / 2,
                    y: (size.height - height) / 2,
                    width: width,
                    height: height
                )
                bars.addRoundedRect(in: rect, cornerSize: CGSize(width: width / 2, height: width / 2), style: .continuous)
            }
            context.fill(
                bars,
                with: .linearGradient(
                    Gradient(colors: colors),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
        .accessibilityHidden(true)
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
