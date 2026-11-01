import Domain
import DomainTestSupport
@testable import FoldersFeature
import Testing

struct FolderSearchTests {
    private let rock = Folder(name: "Rock", sortIndex: 0)
    private let jazz = Folder(name: "Jazz", sortIndex: 1)

    private var live: Folder {
        Folder(id: liveID, name: "Live Rock", parentID: rock.id)
    }

    private let liveID = Folder.ID()

    private var folders: [Folder] {
        [rock, jazz, live]
    }

    private var tracks: [Track] {
        [
            .fixture("Rock Loose", artist: "Beyoncé"),
            .fixture("Anthem", artist: "Rockers", folderID: rock.id),
            .fixture("Encore", album: "Rock Live", folderID: liveID),
            .fixture("Blue in Green", artist: "Miles Davis", folderID: jazz.id),
        ]
    }

    @Test func rootSearchCoversTheWholeTreeSorted() {
        let results = FolderSearch.results(for: "rock", in: nil, folders: folders, tracks: tracks)
        #expect(results.folders.map(\.name) == ["Live Rock", "Rock"])
        #expect(results.tracks.map(\.title) == ["Anthem", "Encore", "Rock Loose"])
    }

    @Test func folderSearchIsRecursiveAndExcludesTheFolderItself() {
        let results = FolderSearch.results(for: "rock", in: rock.id, folders: folders, tracks: tracks)
        #expect(results.folders.map(\.name) == ["Live Rock"])
        #expect(results.tracks.map(\.title) == ["Anthem", "Encore"])
    }

    @Test func subfolderSearchDoesNotReachSiblingsOrParents() {
        let results = FolderSearch.results(for: "rock", in: liveID, folders: folders, tracks: tracks)
        #expect(results.folders.isEmpty)
        #expect(results.tracks.map(\.title) == ["Encore"])
    }

    @Test func everyTermMustMatchIgnoringCaseAndDiacritics() {
        #expect(FolderSearch.results(for: "BEYONCE loose", in: nil, folders: folders, tracks: tracks).tracks.map(\.title) == ["Rock Loose"])
        #expect(FolderSearch.results(for: "miles green", in: nil, folders: folders, tracks: tracks).tracks.map(\.title) == ["Blue in Green"])
        #expect(FolderSearch.results(for: "miles rock", in: nil, folders: folders, tracks: tracks).isEmpty)
    }

    @Test func blankQueryFindsNothing() {
        #expect(FolderSearch.results(for: "  ", in: nil, folders: folders, tracks: tracks).isEmpty)
    }
}
