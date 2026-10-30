import Foundation

/// Drops files into the App Group inbox for the main app to import (used by the Share Extension).
/// The extension never touches the database; `InboxProcessor` in the app picks the files up.
public struct InboxWriter: Sendable {
    public let inboxURL: URL

    public init(inboxURL: URL = StoragePaths.inbox) {
        self.inboxURL = inboxURL
    }

    /// Copies `url` into the inbox, keeping its name; adds " 2", " 3"… if the name is taken.
    @discardableResult
    public func add(_ url: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let destination = availableDestination(for: url.lastPathComponent)
        try fileManager.copyItem(at: url, to: destination)
        return destination
    }

    /// Writes raw data (e.g. an item shared as `Data`) under `fileName`.
    @discardableResult
    public func add(_ data: Data, fileName: String) throws -> URL {
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        let destination = availableDestination(for: fileName)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private func availableDestination(for fileName: String) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var candidate = inboxURL.appending(path: fileName)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = inboxURL.appending(path: name)
            counter += 1
        }
        return candidate
    }
}
