import Domain
import Foundation
import Shared

/// `PlaybackState` as a JSON file, written atomically.
public struct FilePlaybackStateRepository: PlaybackStateRepository {
    public let fileURL: URL

    /// - Parameter fileURL: `StoragePaths.playbackState` in the app.
    public init(fileURL: URL = StoragePaths.playbackState) {
        self.fileURL = fileURL
    }

    /// `nil` if nothing was saved yet or the file is unreadable.
    public func load() async -> PlaybackState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(PlaybackState.self, from: data)
    }

    public func save(_ state: PlaybackState) async throws {
        let data = try JSONEncoder().encode(state)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}
