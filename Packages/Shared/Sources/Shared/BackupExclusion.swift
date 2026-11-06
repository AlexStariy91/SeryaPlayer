import Foundation
import OSLog

private let logger = Logger(subsystem: "com.starodub.SeryaPlayer", category: "BackupExclusion")

/// Keeps the app's own storage out of iCloud and computer backups.
///
/// The flag on a directory excludes everything inside it, including files created later, so one call
/// on `StoragePaths.library` covers `Media`, `Artwork`, `Inbox`, the SQLite store with its `-wal`/`-shm`
/// and `PlaybackState.json`.
public enum BackupExclusion {
    /// Creates `directory` if needed and sets `isExcludedFromBackup` on it. Idempotent and never throws:
    /// a failure is logged, because a missing flag must not stop the app from launching.
    @discardableResult
    public static func exclude(_ directory: URL, fileManager: FileManager = .default) -> Bool {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            var url = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
            return true
        } catch {
            logger.error("Could not exclude \(directory.path, privacy: .public) from backup: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Excludes the library and the Files-app inbox. Call on every launch, before anything is written.
    public static func excludeAppStorage(library: URL = StoragePaths.library, documentsInbox: URL = StoragePaths.documentsInbox) {
        exclude(library)
        exclude(documentsInbox)
    }
}
