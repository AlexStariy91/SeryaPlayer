import Domain
import DomainTestSupport
@testable import FoldersFeature
import Foundation
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
}
