import DesignSystem
import SwiftUI
import UIKit

/// Cover shown on the Lock Screen and in Control Center for tracks without artwork.
/// Rendered from DesignSystem's `NoArtworkCover`, the same graphite background and note as the full player
/// without a cover, so the two can't drift apart. Opaque: the system draws it over its own blurred background.
@MainActor
enum NowPlayingPlaceholder {
    static let image: UIImage? = {
        let side: CGFloat = 600
        let renderer = ImageRenderer(content: NoArtworkCover().frame(width: side, height: side))
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }()
}
