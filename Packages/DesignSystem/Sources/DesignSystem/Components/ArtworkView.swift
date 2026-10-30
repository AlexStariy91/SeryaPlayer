import SwiftUI

/// Square artwork loaded from disk. Decoded off the main thread, cached in memory,
/// with a music-note placeholder while loading or when there is no image.
public struct ArtworkView: View {
    private let url: URL?
    private let size: ArtworkSize

    @State private var image: UIImage?
    @Environment(\.displayScale) private var displayScale

    public init(url: URL?, size: ArtworkSize = .row) {
        self.url = url
        self.size = size
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size.points, height: size.points)
        .clipShape(shape)
        .overlay(shape.strokeBorder(SemanticColor.separator.opacity(0.4), lineWidth: 0.5))
        .accessibilityHidden(true)
        .task(id: url) { await load() }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(SemanticColor.fill)
            Image(systemName: "music.note")
                .font(.system(size: size.points * 0.4, weight: .regular))
                .foregroundStyle(SemanticColor.textTertiary)
        }
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }
        let maxPixel = Int((size.points * displayScale).rounded(.up))
        if let hit = ArtworkCache.shared.cached(url, maxPixel: maxPixel) {
            image = hit
            return
        }
        image = await ArtworkCache.shared.image(for: url, maxPixel: maxPixel)
    }
}

#Preview("Artwork") {
    HStack {
        ArtworkView(url: nil, size: .row)
        ArtworkView(url: nil, size: .grid)
    }
    .padding()
}
