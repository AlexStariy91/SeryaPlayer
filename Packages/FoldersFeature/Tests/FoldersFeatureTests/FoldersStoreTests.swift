import Domain
import DomainTestSupport
@testable import FoldersFeature
import Foundation
import Observation
import Testing

@MainActor
struct FoldersStoreTests {
    @Test func countsAndListsAreIndexedForALargeLibrary() async {
        // 10 top folders, each with 5 children; 10,000 tracks spread over all of them plus the root.
        var folders: [Folder] = []
        for top in 0 ..< 10 {
            let parent = Folder(name: "Top \(top)", sortIndex: top)
            folders.append(parent)
            for child in 0 ..< 5 {
                folders.append(Folder(name: "Child \(child)", parentID: parent.id, sortIndex: child))
            }
        }
        let tracks = (0 ..< 10000).map { index -> Track in
            let folderID: Folder.ID? = index % 11 == 0 ? nil : folders[index % folders.count].id
            return .fixture("Song \(index)", folderID: folderID)
        }
        let deps = TestDependencies(folders: folders, tracks: tracks)
        let started = Date()
        let store = await deps.loadedContext().store
        let elapsed = Date().timeIntervalSince(started)

        #expect(store.songCount(in: nil) == 10000)
        #expect(store.tracks(in: nil).count == tracks.filter { $0.folderID == nil }.count)
        for top in folders.prefix(1) {
            let expected = tracks.filter { track in
                track.folderID == top.id || folders.contains { $0.id == track.folderID && $0.parentID == top.id }
            }.count
            #expect(store.songCount(in: top.id) == expected)
            #expect(store.playableTracks(in: top.id).count == expected)
        }
        #expect(store.subfolders(of: nil).map(\.name).first == "Top 0")
        #expect(elapsed < 5, "rebuild of 10k tracks took \(elapsed)s")
    }

    @Test func loadingTracksPrefetchesTheirArtworkURLs() async {
        var withArt = Track.fixture("With Art")
        withArt.artworkKey = "cover"
        let deps = TestDependencies(tracks: [withArt, .fixture("Without Art")])
        let context = FoldersContext(dependencies: deps)
        let observer = Task { await context.store.observe() }
        defer { observer.cancel() }
        #expect(await eventually { context.artwork.cachedURL(for: "cover", size: .thumbnail) != nil })
        #expect(context.artwork.cachedURL(for: "cover", size: .large) == nil)
    }

    /// A view that reads a folder's count must be invalidated when tracks change, or the row keeps a stale subtitle.
    @Test func deletingTracksInvalidatesViewsReadingTheFolderCount() async throws {
        let parent = Folder(name: "Music")
        let child = Folder(name: "Rock", parentID: parent.id)
        let tracks = (0 ..< 5).map { Track.fixture("Song \($0)", folderID: $0 < 3 ? parent.id : child.id) }
        let deps = TestDependencies(folders: [parent, child], tracks: tracks)
        let context = FoldersContext(dependencies: deps)
        let observer = Task { await context.store.observe() }
        defer { observer.cancel() }
        let store = context.store
        #expect(await eventually { store.songCount(in: parent.id) == 5 })

        let invalidated = Flag()
        withObservationTracking { _ = store.songCount(in: parent.id) } onChange: { invalidated.set() }
        try await deps.tracks.delete(ids: [tracks[0].id, tracks[4].id])
        #expect(await eventually { store.songCount(in: parent.id) == 3 })
        #expect(invalidated.isSet)
        #expect(store.songCount(in: child.id) == 1)
    }

    @Test func tracksArrivingInBatchesKeepTheCountCurrent() async throws {
        let folder = Folder(name: "Imported")
        let deps = TestDependencies(folders: [folder])
        let context = FoldersContext(dependencies: deps)
        let observer = Task { await context.store.observe() }
        defer { observer.cancel() }
        let store = context.store
        #expect(await eventually { store.isLoaded })

        for batch in 0 ..< 3 {
            let invalidated = Flag()
            withObservationTracking { _ = store.songCount(in: folder.id) } onChange: { invalidated.set() }
            try await deps.tracks.add((0 ..< 10).map { .fixture("B\(batch) \($0)", folderID: folder.id) })
            #expect(await eventually { store.songCount(in: folder.id) == (batch + 1) * 10 })
            #expect(invalidated.isSet)
        }
    }
}

/// Set from `withObservationTracking`'s `@Sendable` onChange.
private final class Flag: @unchecked Sendable { // Touched under the lock only.
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.withLock { value }
    }

    func set() {
        lock.withLock { value = true }
    }
}
