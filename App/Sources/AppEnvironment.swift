import DataLayer
import Foundation
import Shared

/// Where the container keeps its data.
///
/// `live` uses the App Group container. `uiTesting` (launch argument `-uiTesting`) uses an
/// in-memory store and a fresh temporary directory, so every UI test run starts empty.
struct AppEnvironment {
    var store: PersistenceController.StoreKind
    var libraryURL: URL
    var documentsInboxURL: URL
    var playbackStateURL: URL
    var defaults: UserDefaults
    /// UI tests only: audio files imported on launch (`SP_UITEST_SEED_DIR`), so tests start with a library.
    var seedDirectory: URL?
    /// UI tests only (`SP_UITEST_HOLD_IMPORT=1`): shows import progress before the seed import and keeps it open
    /// after it, so a test can work with the progress ring while the library fills.
    var holdsImportOpen = false

    static var live: AppEnvironment {
        AppEnvironment(
            store: .file(StoragePaths.database),
            libraryURL: StoragePaths.library,
            documentsInboxURL: StoragePaths.documentsInbox,
            playbackStateURL: StoragePaths.playbackState,
            defaults: AppGroup.userDefaults
        )
    }

    static func uiTesting() -> AppEnvironment {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "SeryaPlayerUITests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let suiteName = "SeryaPlayerUITests"
        UserDefaults().removePersistentDomain(forName: suiteName)
        return AppEnvironment(
            store: .inMemory,
            libraryURL: root.appending(path: "Library", directoryHint: .isDirectory),
            documentsInboxURL: root.appending(path: "Inbox", directoryHint: .isDirectory),
            playbackStateURL: root.appending(path: "PlaybackState.json"),
            defaults: UserDefaults(suiteName: suiteName) ?? .standard,
            seedDirectory: ProcessInfo.processInfo.environment["SP_UITEST_SEED_DIR"]
                .map { URL(fileURLWithPath: $0, isDirectory: true) },
            holdsImportOpen: ProcessInfo.processInfo.environment["SP_UITEST_HOLD_IMPORT"] != nil
        )
    }

    static func current(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        arguments.contains("-uiTesting") ? uiTesting() : live
    }
}
