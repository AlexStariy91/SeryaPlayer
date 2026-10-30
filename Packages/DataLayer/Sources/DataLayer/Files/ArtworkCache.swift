import CryptoKit
import Domain
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Artwork on disk, keyed by the SHA-256 of the image data, so every track of an album shares
/// one file set:
/// - `<key>.<ext>` — the original bytes;
/// - `<key>_thumb.jpg` (~240 px) and `<key>_large.jpg` (~1000 px) — downscaled copies.
///
/// `clearCache` removes only the downscaled copies; they are rebuilt from the original on demand,
/// so artwork keys stored in the database stay valid.
public struct ArtworkCache: ArtworkStoring {
    public enum Error: Swift.Error, Equatable {
        case notAnImage
    }

    static let thumbnailPixelSize = 240
    static let largePixelSize = 1000

    public let directoryURL: URL

    /// - Parameter directoryURL: `StoragePaths.artwork` in the app (`FileStore.artworkURL` for the same root).
    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public func store(_ data: Data) async throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let type = CGImageSourceGetType(source)
        else {
            throw Error.notAnImage
        }
        let key = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let ext = UTType(type as String)?.preferredFilenameExtension ?? "img"
        let original = directoryURL.appending(path: "\(key).\(ext)")
        if !FileManager.default.fileExists(atPath: original.path) {
            try data.write(to: original, options: .atomic)
        }
        for size in [ArtworkSize.thumbnail, .large] {
            _ = try? resizedCopy(of: source, key: key, size: size)
        }
        return key
    }

    public func url(for key: String, size: ArtworkSize) async -> URL? {
        let resized = resizedURL(key: key, size: size)
        if FileManager.default.fileExists(atPath: resized.path) {
            return resized
        }
        // Rebuild after `clearCache`; fall back to the original if that fails.
        guard let original = originalURL(key: key) else { return nil }
        if let source = CGImageSourceCreateWithURL(original as CFURL, nil),
           let url = try? resizedCopy(of: source, key: key, size: size) {
            return url
        }
        return original
    }

    public func clearCache() async throws {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else { return }
        for url in contents where url.lastPathComponent.hasSuffix("_thumb.jpg") || url.lastPathComponent.hasSuffix("_large.jpg") {
            try fileManager.removeItem(at: url)
        }
    }

    // MARK: - Helpers

    func originalURL(key: String) -> URL? {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path)) ?? []
        return contents
            .first { $0.hasPrefix("\(key).") }
            .map { directoryURL.appending(path: $0) }
    }

    func resizedURL(key: String, size: ArtworkSize) -> URL {
        switch size {
        case .thumbnail: directoryURL.appending(path: "\(key)_thumb.jpg")
        case .large: directoryURL.appending(path: "\(key)_large.jpg")
        }
    }

    private func resizedCopy(of source: CGImageSource, key: String, size: ArtworkSize) throws -> URL {
        let destination = resizedURL(key: key, size: size)
        if FileManager.default.fileExists(atPath: destination.path) {
            return destination
        }
        let maxPixelSize = switch size {
        case .thumbnail: Self.thumbnailPixelSize
        case .large: Self.largePixelSize
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Error.notAnImage
        }
        let data = NSMutableData()
        guard let output = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw Error.notAnImage
        }
        CGImageDestinationAddImage(output, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(output) else { throw Error.notAnImage }
        try (data as Data).write(to: destination, options: .atomic)
        return destination
    }
}
