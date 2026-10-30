import Domain
import DomainTestSupport
import Foundation
import Testing

private struct Fixture {
    let files = FakeFileStore()
    let metadata = FakeMetadataReader()
    let artwork = FakeArtworkStore()
    let folders = InMemoryFolderRepository()
    let tracks: InMemoryTrackRepository

    init() {
        tracks = InMemoryTrackRepository(folders: folders)
    }

    var useCase: ImportTracksUseCase {
        ImportTracksUseCase(files: files, metadata: metadata, artwork: artwork, tracks: tracks, folders: folders)
    }
}

private func makeTempTree(_ paths: [String]) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString)")
    for path in paths {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: url)
    }
    return root
}

struct ImportTracksUseCaseTests {
    private static func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/nonexistent/\(name)")
    }

    @Test func importsWithMetadata() async {
        let f = Fixture()
        f.metadata.set(
            TrackMetadata(title: "Song", artist: "Band", album: "LP", trackNumber: 3, duration: 123, artworkData: Data([1, 2])),
            forFileNamed: "a.mp3"
        )
        let result = await f.useCase(urls: [Self.url("a.mp3")], intoFolder: nil)
        #expect(result.added.count == 1)
        let track = result.added[0]
        #expect(track.title == "Song")
        #expect(track.artist == "Band")
        #expect(track.album == "LP")
        #expect(track.trackNumber == 3)
        #expect(track.duration == 123)
        #expect(track.artworkKey == "art-2")
        #expect(track.originalFileName == "a.mp3")
        #expect(track.relativePath.hasPrefix("Media/"))
        #expect(f.tracks.snapshot == [track])
    }

    @Test func titleFallsBackToFileName() async {
        let f = Fixture()
        f.metadata.set(TrackMetadata(title: "  ", duration: 10), forFileNamed: "My Song.flac")
        let result = await f.useCase(urls: [Self.url("My Song.flac"), Self.url("other.mp3")], intoFolder: nil)
        #expect(result.added.map(\.title) == ["My Song", "other"])
    }

    @Test func importsIntoGivenFolder() async {
        let f = Fixture()
        let folder = UUID()
        let result = await f.useCase(urls: [Self.url("a.mp3")], intoFolder: folder)
        #expect(result.added[0].folderID == folder)
    }

    @Test func duplicateInLibraryIsSkippedBeforeCopying() async throws {
        let f = Fixture()
        try await f.tracks.add([.fixture("old", contentHash: "same")])
        f.files.setHash("same", forFileNamed: "a.mp3")
        let result = await f.useCase(urls: [Self.url("a.mp3")], intoFolder: nil)
        #expect(result.duplicates == ["a.mp3"])
        #expect(result.added.isEmpty)
        #expect(f.files.importedFiles.isEmpty)
        #expect(f.tracks.snapshot.count == 1)
    }

    @Test func duplicateWithinBatchIsSkipped() async {
        let f = Fixture()
        f.files.setHash("h", forFileNamed: "a.mp3")
        f.files.setHash("h", forFileNamed: "b.mp3")
        let result = await f.useCase(urls: [Self.url("a.mp3"), Self.url("b.mp3")], intoFolder: nil)
        #expect(result.added.count == 1)
        #expect(result.duplicates == ["b.mp3"])
        #expect(f.files.importedFiles.count == 1)
    }

    @Test func unsupportedFormatIsReportedAndNotCopied() async {
        let f = Fixture()
        f.metadata.markUnsupported(["a.xyz"])
        let result = await f.useCase(urls: [Self.url("a.xyz"), Self.url("b.mp3")], intoFolder: nil)
        #expect(result.unsupported == ["a.xyz"])
        #expect(result.added.map(\.originalFileName) == ["b.mp3"])
        #expect(f.files.importedFiles.count == 1)
    }

    @Test func unreadableAndFailingFilesGoToFailed() async {
        let f = Fixture()
        f.metadata.markUnreadable(["bad.mp3"])
        f.files.failImport(of: ["io.mp3"])
        let result = await f.useCase(urls: [Self.url("bad.mp3"), Self.url("io.mp3"), Self.url("ok.mp3")], intoFolder: nil)
        #expect(result.failed == ["bad.mp3", "io.mp3"])
        #expect(result.added.count == 1)
    }

    @Test func progressIsReported() async {
        let f = Fixture()
        let log = ProgressLog()
        _ = await f.useCase(urls: [Self.url("a.mp3"), Self.url("b.mp3")], intoFolder: nil) { log.append($0) }
        #expect(log.values == [
            ImportProgress(completed: 0, total: 2),
            ImportProgress(completed: 1, total: 2),
            ImportProgress(completed: 2, total: 2),
        ])
    }

    @Test func folderImportRepeatsStructure() async throws {
        let f = Fixture()
        let root = try makeTempTree(["Album/01.mp3", "Album/02.mp3", "Album/Live/03.mp3", "Album/.hidden"])
        defer { try? FileManager.default.removeItem(at: root) }
        let result = await f.useCase(urls: [root.appendingPathComponent("Album")], intoFolder: nil)

        #expect(result.added.count == 3)
        let folders = f.folders.snapshot
        let album = try #require(folders.first { $0.name == "Album" })
        let live = try #require(folders.first { $0.name == "Live" })
        #expect(album.parentID == nil)
        #expect(live.parentID == album.id)
        #expect(folders.count == 2)
        let byName = Dictionary(uniqueKeysWithValues: result.added.map { ($0.originalFileName, $0.folderID) })
        #expect(byName["01.mp3"] == album.id)
        #expect(byName["02.mp3"] == album.id)
        #expect(byName["03.mp3"] == live.id)
    }

    @Test func folderImportIntoExistingFolder() async throws {
        let f = Fixture()
        let parent = Folder(name: "Parent")
        try await f.folders.create(parent)
        let root = try makeTempTree(["Sub/a.mp3"])
        defer { try? FileManager.default.removeItem(at: root) }
        _ = await f.useCase(urls: [root.appendingPathComponent("Sub")], intoFolder: parent.id)
        #expect(f.folders.snapshot.first { $0.name == "Sub" }?.parentID == parent.id)
    }

    @Test func reimportingFolderReusesFoldersAndSkipsDuplicates() async throws {
        let f = Fixture()
        let root = try makeTempTree(["Album/a.mp3"])
        defer { try? FileManager.default.removeItem(at: root) }
        let album = root.appendingPathComponent("Album")
        _ = await f.useCase(urls: [album], intoFolder: nil)
        let second = await f.useCase(urls: [album], intoFolder: nil)
        #expect(f.folders.snapshot.count == 1)
        #expect(second.duplicates == ["a.mp3"])
        #expect(second.added.isEmpty)
    }
}

private final class ProgressLog: @unchecked Sendable { // test-only; guarded by the lock
    private let lock = NSLock()
    private var storage: [ImportProgress] = []

    func append(_ value: ImportProgress) {
        lock.withLock { storage.append(value) }
    }

    var values: [ImportProgress] {
        lock.withLock { storage }
    }
}
