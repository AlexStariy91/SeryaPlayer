import SwiftUI

/// Square artwork loaded from disk. Decoded off the main thread, cached in memory,
/// with a music-note placeholder while loading or when there is no image.
///
/// A cached image is shown in the first render, without a `.task` or a state change, so list rows that
/// scroll back into view cost one layout pass instead of placeholder → image → re-layout.
public struct ArtworkView: View {
    private let url: URL?
    private let size: ArtworkSize
    private let placeholderStyle: ArtworkPlaceholderStyle

    /// The last decoded image with the URL it belongs to, so a reused view never shows another URL's image.
    @State private var loaded: Loaded?
    @Environment(\.displayScale) private var displayScale

    public init(url: URL?, size: ArtworkSize = .row, placeholderStyle: ArtworkPlaceholderStyle = .standard) {
        self.url = url
        self.size = size
        self.placeholderStyle = placeholderStyle
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
        ZStack {
            Rectangle().fill(placeholderStyle.fill)
            Image(systemName: "music.note")
                .font(.system(size: size.points * 0.4, weight: .regular))
                .foregroundStyle(placeholderStyle.note)
        }
    }

    private func load() async {
        guard let url, let image = await ArtworkCache.shared.image(for: url, maxPixel: maxPixel), !Task.isCancelled else { return }
        loaded = Loaded(url: url, image: image)
    }
}

/// How strongly `ArtworkView` draws its placeholder.
public enum ArtworkPlaceholderStyle: Sendable {
    /// A faint tile for lists, grids and the mini player.
    case standard
    /// A stronger fill and note, for the full player, where the tile sits on a dark mesh background and must read
    /// as a lighter square.
    case prominent

    var fill: Color {
        switch self {
        case .standard: SemanticColor.fill
        case .prominent: Color(uiColor: .systemFill)
        }
    }

    var note: Color {
        switch self {
        case .standard: SemanticColor.textTertiary
        case .prominent: SemanticColor.textSecondary
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
