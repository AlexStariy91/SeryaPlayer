import CryptoKit
@testable import DataLayer
import Domain
import Foundation
import ImageIO
import Testing

struct FileStoreTests {
    let directory: TemporaryDirectory
    let store: FileStore

    init() throws {
        directory = try TemporaryDirectory()
        store = FileStore(rootURL: directory.url.appending(path: "Library"), documentsInboxURL: directory.url.appending(path: "Documents/Inbox"))
    }

    private func writeSource(_ name: String, bytes: Int) throws -> URL {
        let url = directory.url.appending(path: name)
        try Data((0 ..< bytes).map { UInt8(truncatingIfNeeded: $0 * 31) }).write(to: url)
        return url
    }

    @Test func contentHashIsSizePlusSHA256OfFirstMegabyte() async throws {
        defer { directory.cleanUp() }
        let source = try writeSource("big.mp3", bytes: 1_500_000)
        let data = try Data(contentsOf: source)
        let expected = SHA256.hash(data: data.prefix(1024 * 1024)).map { String(format: "%02x", $0) }.joined()

        #expect(try await store.contentHash(of: source) == "1500000-\(expected)")

        // Same head, different size → different hash.
        let longer = try writeSource("longer.mp3", bytes: 1_600_000)
        let longerHash = try await store.contentHash(of: longer)
        #expect(try await longerHash != store.contentHash(of: source))
    }

    @Test func importCopiesUnderUUIDNameKeepingExtension() async throws {
        defer { directory.cleanUp() }
        let source = try writeSource("My Song.FLAC", bytes: 2048)

        let stored = try await store.importFile(from: source)

        #expect(stored.relativePath.hasPrefix("Media/"))
        #expect(stored.relativePath.hasSuffix(".flac"))
        #expect(UUID(uuidString: String(stored.relativePath.dropFirst("Media/".count).dropLast(".flac".count))) != nil)
        #expect(stored.originalFileName == "My Song.FLAC")
        #expect(stored.fileSize == 2048)
        let sourceHash = try await store.contentHash(of: source)
        #expect(stored.contentHash == sourceHash)
        let copy = store.url(forRelativePath: stored.relativePath)
        #expect(try Data(contentsOf: copy) == Data(contentsOf: source))
        #expect(FileManager.default.fileExists(atPath: source.path), "The original is left in place")
        #expect(await store.librarySize() >= 2048)

        try await store.deleteFile(relativePath: stored.relativePath)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        #expect(await store.librarySize() == 0)
        try await store.deleteFile(relativePath: stored.relativePath) // missing file is not an error
    }

    @Test func pendingInboxFilesComeFromBothInboxes() async throws {
        defer { directory.cleanUp() }
        #expect(await store.pendingInboxFiles().isEmpty)

        let shared = store.inboxURL.appending(path: "shared.mp3")
        let documents = store.documentsInboxURL.appending(path: "documents.m4a")
        try Data("a".utf8).write(to: shared)
        try Data("b".utf8).write(to: documents)
        try Data("hidden".utf8).write(to: store.inboxURL.appending(path: ".DS_Store"))
        try FileManager.default.createDirectory(at: store.inboxURL.appending(path: "Subfolder"), withIntermediateDirectories: true)

        let pending = await store.pendingInboxFiles()
        #expect(Set(pending.map(\.lastPathComponent)) == ["shared.mp3", "documents.m4a"])

        for url in pending {
            try await store.removeFromInbox(url)
        }
        #expect(await store.pendingInboxFiles().isEmpty)
    }

    @Test func removeFromInboxRefusesFilesOutsideTheInboxes() async throws {
        defer { directory.cleanUp() }
        let outside = try writeSource("keep.mp3", bytes: 10)
        await #expect(throws: CocoaError.self) {
            try await store.removeFromInbox(outside)
        }
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }
}

struct ArtworkCacheTests {
    static func makeImage(width: Int, height: Int, red: UInt8) throws -> Data {
        // Uncompressed 24-bit BMP: no image libraries needed on either platform.
        let rowSize = (width * 3 + 3) & ~3
        let pixelBytes = rowSize * height
        var data = Data()
        func append(_ value: some FixedWidthInteger) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("BM".utf8))
        append(UInt32(54 + pixelBytes)); append(UInt32(0)); append(UInt32(54))
        append(UInt32(40)); append(Int32(width)); append(Int32(height)); append(UInt16(1)); append(UInt16(24))
        append(UInt32(0)); append(UInt32(pixelBytes)); append(Int32(2835)); append(Int32(2835)); append(UInt32(0)); append(UInt32(0))
        let row = (0 ..< width).flatMap { _ in [UInt8(40), UInt8(80), red] } + Array(repeating: UInt8(0), count: rowSize - width * 3)
        for _ in 0 ..< height {
            data.append(contentsOf: row)
        }
        return data
    }

    static func pixelSize(of url: URL) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    @Test func storesOriginalAndDownscaledCopiesOncePerImage() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.cleanUp() }
        let cache = ArtworkCache(directoryURL: directory.url.appending(path: "Artwork"))
        let image = try Self.makeImage(width: 1600, height: 1200, red: 200)

        let key = try await cache.store(image)
        let sameKey = try await cache.store(image)
        let otherKey = try await cache.store(Self.makeImage(width: 100, height: 100, red: 10))

        #expect(key == sameKey)
        #expect(key != otherKey)
        #expect(key == SHA256.hash(data: image).map { String(format: "%02x", $0) }.joined())

        let thumbnail = try #require(await cache.url(for: key, size: .thumbnail))
        let large = try #require(await cache.url(for: key, size: .large))
        #expect(Self.pixelSize(of: thumbnail).map { max($0.0, $0.1) } == 240)
        #expect(Self.pixelSize(of: large).map { max($0.0, $0.1) } == 1000)

        // Two images → two originals + four resized copies.
        let files = try FileManager.default.contentsOfDirectory(atPath: cache.directoryURL.path)
        #expect(files.count == 6)
    }

    @Test func clearCacheKeepsOriginalsAndRebuildsCopiesOnDemand() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.cleanUp() }
        let cache = ArtworkCache(directoryURL: directory.url.appending(path: "Artwork"))
        let key = try await cache.store(Self.makeImage(width: 500, height: 500, red: 1))

        #expect(await cache.cacheSize() > 0)
        try await cache.clearCache()
        #expect(await cache.cacheSize() == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: cache.directoryURL.path).count == 1)

        let thumbnail = try #require(await cache.url(for: key, size: .thumbnail))
        #expect(thumbnail.lastPathComponent == "\(key)_thumb.jpg")
        #expect(await cache.url(for: "unknown", size: .large) == nil)
    }

    @Test func rejectsNonImageData() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.cleanUp() }
        let cache = ArtworkCache(directoryURL: directory.url)
        await #expect(throws: ArtworkCache.Error.notAnImage) {
            try await cache.store(Data("nope".utf8))
        }
    }
}
