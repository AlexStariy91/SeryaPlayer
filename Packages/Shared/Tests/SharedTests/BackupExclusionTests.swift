import Foundation
@testable import Shared
import Testing

struct BackupExclusionTests {
    @Test func excludesLibraryAndInboxAndIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "BackupExclusionTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let library = root.appending(path: "Library", directoryHint: .isDirectory)
        let inbox = root.appending(path: "Documents/Inbox", directoryHint: .isDirectory)

        BackupExclusion.excludeAppStorage(library: library, documentsInbox: inbox)
        BackupExclusion.excludeAppStorage(library: library, documentsInbox: inbox)

        #expect(try library.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        #expect(try inbox.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }

    @Test func flagsExistingDirectory() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "BackupExclusionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(BackupExclusion.exclude(dir))
        #expect(try dir.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
    }
}
