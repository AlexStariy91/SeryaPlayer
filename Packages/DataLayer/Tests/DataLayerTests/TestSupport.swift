@testable import DataLayer
import Domain
import Foundation

struct TimeoutError: Error {}

/// Waits for the first stream element that satisfies `predicate`, failing after `timeout`.
func value<T: Sendable>(
    from stream: AsyncStream<T>,
    timeout: Duration = .seconds(5),
    where predicate: @escaping @Sendable (T) -> Bool = { _ in true }
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            for await element in stream where predicate(element) {
                return element
            }
            throw CancellationError()
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw TimeoutError()
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

func makeTrack(
    title: String,
    artist: String = "Artist",
    album: String = "Album",
    folderID: Folder.ID? = nil,
    dateAdded: Date = .now,
    hash: String? = nil
) -> Track {
    let id = UUID()
    return Track(
        id: id,
        title: title,
        artist: artist,
        album: album,
        duration: 180,
        relativePath: "Media/\(id.uuidString).mp3",
        originalFileName: "\(title).mp3",
        fileSize: 1000,
        contentHash: hash ?? "1000-\(id.uuidString)",
        folderID: folderID,
        dateAdded: dateAdded
    )
}

/// A unique temporary directory, removed by the caller with `cleanUp()`.
struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "DataLayerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: url)
    }
}
