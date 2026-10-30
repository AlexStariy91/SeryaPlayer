import ImageIO
import UIKit

/// In-memory cache of decoded artwork plus an off-main-thread loader.
final class ArtworkCache: @unchecked Sendable {
    /// NSCache is thread-safe, and the stored UIImages are immutable once decoded.
    static let shared = ArtworkCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    private func key(_ url: URL, _ maxPixel: Int) -> NSString {
        "\(url.absoluteString)#\(maxPixel)" as NSString
    }

    func cached(_ url: URL, maxPixel: Int) -> UIImage? {
        cache.object(forKey: key(url, maxPixel))
    }

    /// Decodes a downsampled image on the global executor, not the main actor, and caches it.
    func image(for url: URL, maxPixel: Int) async -> UIImage? {
        if let hit = cached(url, maxPixel: maxPixel) {
            return hit
        }
        guard let decoded = Self.decode(url, maxPixel: maxPixel) else { return nil }
        let cost = decoded.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(decoded, forKey: key(url, maxPixel), cost: cost)
        return decoded
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private static func decode(_ url: URL, maxPixel: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
