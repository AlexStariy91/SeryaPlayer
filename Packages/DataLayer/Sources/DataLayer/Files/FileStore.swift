import CryptoKit
import Domain
import Foundation
import Shared

/// Audio files in the library container:
/// `<root>/Media/<uuid>.<ext>`, `<root>/Artwork`, `<root>/Inbox`, plus the Documents inbox.
public struct FileStore: FileStoring {
    /// How much of the file head goes into `contentHash`.
    static let hashedPrefixLength = 1024 * 1024

    public let rootURL: URL
    public let documentsInboxURL: URL

    public var mediaURL: URL {
        rootURL.appending(path: "Media", directoryHint: .isDirectory)
    }

    public var artworkURL: URL {
        rootURL.appending(path: "Artwork", directoryHint: .isDirectory)
    }

    public var inboxURL: URL {
        rootURL.appending(path: "Inbox", directoryHint: .isDirectory)
    }

    /// - Parameters:
    ///   - rootURL: the library root; `StoragePaths.library` in the app, a temp folder in tests.
    ///   - documentsInboxURL: `Documents/Inbox`, visible in the Files app.
    public init(rootURL: URL = StoragePaths.library, documentsInboxURL: URL = StoragePaths.documentsInbox) {
        self.rootURL = rootURL
        self.documentsInboxURL = documentsInboxURL
    }

    /// `"<size>-<sha256 of the first 1 MB, hex>"`.
    public func contentHash(of url: URL) async throws -> String {
        try withSecurityScopedAccess(to: url) {
            try Self.hash(of: url)
        }
    }

    public func importFile(from url: URL) async throws -> StoredFile {
        try withSecurityScopedAccess(to: url) {
            let fileManager = FileManager.default
            try fileManager.createDirectory(at: mediaURL, withIntermediateDirectories: true)
            let fileName = url.pathExtension.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(url.pathExtension.lowercased())"
            let relativePath = "Media/\(fileName)"
            let destination = self.url(forRelativePath: relativePath)
            try fileManager.copyItem(at: url, to: destination)
            do {
                let hash = try Self.hash(of: destination)
                return try StoredFile(
                    relativePath: relativePath,
                    originalFileName: url.lastPathComponent,
                    fileSize: Self.size(of: destination),
                    contentHash: hash
                )
            } catch {
                try? fileManager.removeItem(at: destination)
                throw error
            }
        }
    }

    public func url(forRelativePath path: String) -> URL {
        rootURL.appending(path: path, directoryHint: .notDirectory)
    }

    public func deleteFile(relativePath: String) async throws {
        let url = url(forRelativePath: relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// Total size of `Media/`, bytes.
    public func librarySize() async -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: mediaURL, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    /// Regular, non-hidden files from both inboxes, oldest first. Missing inboxes are created.
    public func pendingInboxFiles() async -> [URL] {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey]
        var files: [(url: URL, created: Date)] = []
        for inbox in [inboxURL, documentsInboxURL] {
            try? fileManager.createDirectory(at: inbox, withIntermediateDirectories: true)
            let contents = (try? fileManager.contentsOfDirectory(at: inbox, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
            for url in contents {
                guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
                files.append((url, values.creationDate ?? .distantPast))
            }
        }
        return files.sorted { ($0.created, $0.url.lastPathComponent) < ($1.created, $1.url.lastPathComponent) }.map(\.url)
    }

    public func removeFromInbox(_ url: URL) async throws {
        let target = url.standardizedFileURL.resolvingSymlinksInPath()
        let isInInbox = [inboxURL, documentsInboxURL].contains {
            target.deletingLastPathComponent().path == $0.standardizedFileURL.resolvingSymlinksInPath().path
        }
        guard isInInbox else { throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: url.path]) }
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        try FileManager.default.removeItem(at: target)
    }

    // MARK: - Helpers

    private func withSecurityScopedAccess<T>(to url: URL, _ body: () throws -> T) throws -> T {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body()
    }

    static func size(of url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    static func hash(of url: URL) throws -> String {
        let size = try size(of: url)
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let head = try handle.read(upToCount: hashedPrefixLength) ?? Data()
        let digest = SHA256.hash(data: head).map { String(format: "%02x", $0) }.joined()
        return "\(size)-\(digest)"
    }
}
