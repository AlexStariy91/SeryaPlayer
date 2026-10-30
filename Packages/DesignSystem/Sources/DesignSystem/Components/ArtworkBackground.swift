import SwiftUI

/// Full-player background: a mesh gradient from 3–4 artwork colors. Slightly darkened so text stays legible.
public struct ArtworkBackground: View {
    private let colors: [Color]

    public init(colors: [Color]) {
        self.colors = colors
    }

    public var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: meshColors
        )
        .overlay(Color.black.opacity(0.2))
        .animation(.easeInOut(duration: 0.6), value: colors)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// Spreads 1–4 colors over the 9 mesh points; falls back to the accent when empty.
    private var meshColors: [Color] {
        let base = colors.isEmpty ? [AccentPalette.serya.color] : Array(colors.prefix(4))
        let order = [0, 1, 2, 3, 0, 1, 2, 3, 0]
        return order.map { base[$0 % base.count] }
    }
}

#Preview("Background") {
    ArtworkBackground(colors: [.indigo, .pink, .orange, .teal])
}
