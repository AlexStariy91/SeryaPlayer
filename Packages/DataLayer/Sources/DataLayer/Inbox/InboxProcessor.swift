import Domain
import Foundation

/// Imports files dropped into the inboxes (Share Extension, Files app) and clears them.
///
/// The import itself is the Domain use case, passed in as `importer`. After it returns, every file is
/// removed from the inbox except those reported in `ImportResult.failed` (matched by file name or
/// path), which are kept for a retry on the next activation. Concurrent calls are serialized.
public actor InboxProcessor {
    public typealias Importer = @Sendable ([URL]) async -> ImportResult

    private let fileStore: any FileStoring
    private let importer: Importer
    private var running: Task<ImportResult, Never>?

    public init(fileStore: any FileStoring, importer: @escaping Importer) {
        self.fileStore = fileStore
        self.importer = importer
    }

    /// Call on every app activation. Returns an empty result when the inboxes are empty.
    @discardableResult
    public func process() async -> ImportResult {
        if let running {
            return await running.value
        }
        let task = Task { await run() }
        running = task
        let result = await task.value
        running = nil
        return result
    }

    private func run() async -> ImportResult {
        let files = await fileStore.pendingInboxFiles()
        guard !files.isEmpty else { return ImportResult() }
        let result = await importer(files)
        let failed = Set(result.failed)
        for file in files where !failed.contains(file.lastPathComponent) && !failed.contains(file.path) {
            try? await fileStore.removeFromInbox(file)
        }
        return result
    }
}
