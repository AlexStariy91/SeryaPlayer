import SwiftUI

/// The cover of a track without artwork outside the app (Lock Screen, Control Center): the full player's
/// no-artwork background with the note of its placeholder. Always dark, like the full player, and opaque, so it
/// can be rendered to an image (`ImageRenderer`) that the system draws over its own background.
public struct NoArtworkCover: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            Image(systemName: "music.note")
                .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.4, weight: .regular))
                .foregroundStyle(ArtworkPlaceholderStyle.prominent.note)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background { ArtworkBackground(colors: []) }
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }
}

#Preview("No artwork cover") {
    NoArtworkCover()
        .frame(width: 300, height: 300)
}
