import SwiftUI

/// Square artwork loaded from disk. Decoded off the main thread, cached in memory,
/// with a music-note placeholder while loading or when there is no image.
///
/// A cached image is shown in the first render, without a `.task` or a state change, so list rows that
/// scroll back into view cost one layout pass instead of placeholder → image → re-layout.
public struct ArtworkView: View {
    private let url: URL?
    private let size: ArtworkSize

    /// The last decoded image with the URL it belongs to, so a reused view never shows another URL's image.
    @State private var loaded: Loaded?
    @Environment(\.displayScale) private var displayScale

    public init(url: URL?, size: ArtworkSize = .row) {
        self.url = url
        self.size = size
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
        ZStack {
            if let image = currentImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
                    // Only a cache miss pays for a task.
                    .task(id: url) { await load() }
            }
        }
        .frame(width: size.points, height: size.points)
        .clipShape(shape)
        .overlay(shape.strokeBorder(SemanticColor.separator.opacity(0.4), lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    private var maxPixel: Int {
        Int((size.points * displayScale).rounded(.up))
    }

    private var currentImage: UIImage? {
        guard let url else { return nil }
        if let loaded, loaded.url == url {
            return loaded.image
        }
        return ArtworkCache.shared.cached(url, maxPixel: maxPixel)
    }

    private var placeholder: some View {
        ArtworkPlaceholder(side: size.points)
    }

    private func load() async {
        guard let url, let image = await ArtworkCache.shared.image(for: url, maxPixel: maxPixel), !Task.isCancelled else { return }
        loaded = Loaded(url: url, image: image)
    }
}

/// The tile shown for a track without artwork: an opaque grey diagonal gradient with a near-white note, the same
/// look as the Lock Screen placeholder (`NowPlayingPlaceholder` in the App target). Fixed colours, so it reads the
/// same on the full player's coloured background, the mini player's glass or material, and light and dark lists.
struct ArtworkPlaceholder: View {
    let side: CGFloat

    static let topLeading = Color(white: 0.62)
    static let bottomTrailing = Color(white: 0.36)
    static let note = Color(white: 0.96)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Self.topLeading, Self.bottomTrailing],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: side * 0.4, weight: .regular))
                .foregroundStyle(Self.note)
        }
    }
}

private struct Loaded {
    let url: URL
    let image: UIImage
}

#Preview("Artwork") {
    HStack {
        ArtworkView(url: nil, size: .row)
        ArtworkView(url: nil, size: .grid)
    }
    .padding()
}
