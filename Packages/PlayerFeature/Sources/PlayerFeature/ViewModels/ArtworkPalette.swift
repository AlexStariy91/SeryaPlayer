import DesignSystem
import Foundation
import ImageIO
import SwiftUI

/// Background colors for the full player, extracted from the artwork file off the main thread.
enum ArtworkPalette {
    static func colors(from url: URL) async -> [Color] {
        await Task.detached(priority: .utility) {
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 80,
            ] as CFDictionary
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
            else { return [] }
            return DominantColors.extract(from: image)
        }.value
    }
}
