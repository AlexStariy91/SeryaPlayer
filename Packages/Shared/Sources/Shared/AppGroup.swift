import Foundation

public enum AppGroup {
    public static let id = "group.com.starodub.SeryaPlayer"

    /// Root of the shared container. On an unsigned simulator build the App Group is unavailable,
    /// so the app's Application Support directory is used instead.
    public static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url
        }
        return URL.applicationSupportDirectory.appending(path: "SeryaPlayer", directoryHint: .isDirectory)
    }

    public static var userDefaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

public enum StoragePaths {
    public static var library: URL {
        AppGroup.containerURL.appending(path: "Library", directoryHint: .isDirectory)
    }

    public static var media: URL {
        library.appending(path: "Media", directoryHint: .isDirectory)
    }

    public static var artwork: URL {
        library.appending(path: "Artwork", directoryHint: .isDirectory)
    }

    public static var inbox: URL {
        library.appending(path: "Inbox", directoryHint: .isDirectory)
    }

    public static var database: URL {
        library.appending(path: "SeryaPlayer.sqlite")
    }

    public static var playbackState: URL {
        library.appending(path: "PlaybackState.json")
    }

    /// Visible in Finder and the Files app (UIFileSharingEnabled).
    public static var documentsInbox: URL {
        URL.documentsDirectory.appending(path: "Inbox", directoryHint: .isDirectory)
    }
}
