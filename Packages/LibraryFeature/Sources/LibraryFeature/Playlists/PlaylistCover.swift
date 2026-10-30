import DesignSystem
import Domain
import SwiftUI

/// A playlist cover: a 2×2 collage of the first four distinct artworks, a single artwork when
/// there are fewer, or a placeholder.
struct PlaylistCover: View {
    let artworkKeys: [String]
    let size: DesignSystem.ArtworkSize
    let resolver: ArtworkResolver

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
        Group {
            if artworkKeys.count >= 4 {
                let half = DesignSystem.ArtworkSize.custom(size.points / 2)
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        tile(artworkKeys[0], half)
                        tile(artworkKeys[1], half)
                    }
                    GridRow {
                        tile(artworkKeys[2], half)
                        tile(artworkKeys[3], half)
                    }
                }
            } else if let key = artworkKeys.first {
                ResolvedArtwork(key: key, size: size, resolver: resolver)
            } else {
                ZStack {
                    Rectangle().fill(SemanticColor.fill)
                    Image(systemName: "music.note.list")
                        .font(.system(size: size.points * 0.4))
                        .foregroundStyle(SemanticColor.textTertiary)
                }
            }
        }
        .frame(width: size.points, height: size.points)
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private func tile(_ key: String, _ size: DesignSystem.ArtworkSize) -> some View {
        ResolvedArtwork(key: key, size: size, resolver: resolver)
    }

    /// The first four distinct artwork keys in playlist order.
    static func keys(for entries: [PlaylistEntry], tracksByID: [Track.ID: Track]) -> [String] {
        var seen: Set<String> = []
        var keys: [String] = []
        for entry in entries {
            guard let key = tracksByID[entry.trackID]?.artworkKey, seen.insert(key).inserted else { continue }
            keys.append(key)
            if keys.count == 4 {
                break
            }
        }
        return keys
    }
}
