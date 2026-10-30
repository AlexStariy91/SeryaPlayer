import Domain
import DomainTestSupport
import Foundation
import Testing

struct SearchAndObserveTests {
    @Test func searchIsCaseAndDiacriticInsensitive() async throws {
        let repo = InMemoryTrackRepository(tracks: [.fixture("Café", artist: "Zoé"), .fixture("Other")])
        let search = SearchTracksUseCase(tracks: repo)
        #expect(try await search("CAFE").map(\.title) == ["Café"])
        #expect(try await search("zoe").count == 1)
    }

    @Test func blankQueryFindsNothing() async throws {
        let repo = InMemoryTrackRepository(tracks: [.fixture("A")])
        #expect(try await SearchTracksUseCase(tracks: repo)("   ").isEmpty)
    }

    @Test func observeEmitsCurrentThenChanges() async throws {
        let repo = InMemoryTrackRepository(tracks: [.fixture("B"), .fixture("A")])
        var stream = ObserveTracksUseCase(tracks: repo)(sortedBy: TrackSort(field: .title)).makeAsyncIterator()
        #expect(await stream.next()?.map(\.title) == ["A", "B"])
        try await repo.add([.fixture("C")])
        #expect(await stream.next()?.map(\.title) == ["A", "B", "C"])
    }
}

struct FolderUseCaseTests {
    @Test func createTrimsAndAppendsSortIndex() async throws {
        let repo = InMemoryFolderRepository()
        let create = CreateFolderUseCase(folders: repo)
        let first = try await create(name: "  Rock ")
        let second = try await create(name: "Jazz")
        #expect(first.name == "Rock")
        #expect(second.sortIndex == first.sortIndex + 1)
        let child = try await create(name: "Child", parentID: first.id)
        #expect(child.parentID == first.id)
        #expect(child.sortIndex == 0)
    }

    @Test func createRejectsBlankName() async {
        let create = CreateFolderUseCase(folders: InMemoryFolderRepository())
        await #expect(throws: DomainError.emptyName) { try await create(name: "  ") }
    }

    @Test func renameAndNotFound() async throws {
        let folder = Folder(name: "Old")
        let repo = InMemoryFolderRepository(folders: [folder])
        let rename = RenameFolderUseCase(folders: repo)
        try await rename(id: folder.id, to: "New")
        #expect(repo.snapshot.first?.name == "New")
        await #expect(throws: DomainError.folderNotFound) { try await rename(id: UUID(), to: "X") }
        await #expect(throws: DomainError.emptyName) { try await rename(id: folder.id, to: "") }
    }

    @Test func moveFolderAndRejectCycles() async throws {
        let a = Folder(name: "A")
        let b = Folder(name: "B", parentID: a.id)
        let c = Folder(name: "C")
        let repo = InMemoryFolderRepository(folders: [a, b, c])
        let move = MoveFolderUseCase(folders: repo)
        try await move(id: c.id, toParent: b.id)
        #expect(repo.snapshot.first { $0.id == c.id }?.parentID == b.id)
        await #expect(throws: DomainError.folderCycle) { try await move(id: a.id, toParent: c.id) }
        await #expect(throws: DomainError.folderCycle) { try await move(id: a.id, toParent: a.id) }
        try await move(id: c.id, toParent: nil)
        #expect(repo.snapshot.first { $0.id == c.id }?.parentID == nil)
    }
}

struct DeleteFolderUseCaseTests {
    private struct Setup {
        let root = Folder(name: "Root")
        let child: Folder
        let other = Folder(name: "Other")
        let folders: InMemoryFolderRepository
        let tracks: InMemoryTrackRepository
        let files = FakeFileStore()
        let inRoot: Track
        let inChild: Track
        let inOther: Track
        let loose: Track

        init() {
            child = Folder(name: "Child", parentID: root.id)
            folders = InMemoryFolderRepository(folders: [root, child, other])
            inRoot = .fixture("r", folderID: root.id)
            inChild = .fixture("c", folderID: child.id)
            inOther = .fixture("o", folderID: other.id)
            loose = .fixture("l")
            tracks = InMemoryTrackRepository(tracks: [inRoot, inChild, inOther, loose], folders: folders)
        }

        var useCase: DeleteFolderUseCase {
            DeleteFolderUseCase(folders: folders, tracks: tracks, files: files)
        }
    }

    @Test func moveToRootKeepsTracksIncludingNested() async throws {
        let s = Setup()
        try await s.useCase(id: s.root.id, policy: .moveTracksToRoot)
        #expect(s.folders.snapshot.map(\.name) == ["Other"])
        #expect(s.tracks.snapshot.count == 4)
        let byTitle = Dictionary(uniqueKeysWithValues: s.tracks.snapshot.map { ($0.title, $0.folderID) })
        #expect(byTitle["r"] == .some(nil))
        #expect(byTitle["c"] == .some(nil))
        #expect(byTitle["o"] == s.other.id)
        #expect(s.files.deletedPaths.isEmpty)
    }

    @Test func deleteTracksRemovesNestedTracksAndFiles() async throws {
        let s = Setup()
        try await s.useCase(id: s.root.id, policy: .deleteTracks)
        #expect(s.folders.snapshot.map(\.name) == ["Other"])
        #expect(Set(s.tracks.snapshot.map(\.title)) == ["o", "l"])
        #expect(Set(s.files.deletedPaths) == [s.inRoot.relativePath, s.inChild.relativePath])
    }

    @Test func deletingSubfolderLeavesParent() async throws {
        let s = Setup()
        try await s.useCase(id: s.child.id, policy: .deleteTracks)
        #expect(Set(s.folders.snapshot.map(\.name)) == ["Root", "Other"])
        #expect(Set(s.tracks.snapshot.map(\.title)) == ["r", "o", "l"])
    }

    @Test func unknownFolderThrows() async {
        let s = Setup()
        await #expect(throws: DomainError.folderNotFound) { try await s.useCase(id: UUID(), policy: .deleteTracks) }
    }
}

struct PlaylistUseCaseTests {
    @Test func createWithTracksAndAdd() async throws {
        let repo = InMemoryPlaylistRepository()
        let a = UUID(), b = UUID()
        let playlist = try await CreatePlaylistUseCase(playlists: repo)(name: " Mix ", trackIDs: [a])
        #expect(playlist.name == "Mix")
        try await AddTracksToPlaylistUseCase(playlists: repo)(trackIDs: [b, a], to: playlist.id)
        #expect(repo.entries(of: playlist.id).map(\.trackID) == [a, b, a])
    }

    @Test func createRejectsBlankName() async {
        let create = CreatePlaylistUseCase(playlists: InMemoryPlaylistRepository())
        await #expect(throws: DomainError.emptyName) { try await create(name: "") }
    }

    @Test func renameDeleteMoveAndRemove() async throws {
        let repo = InMemoryPlaylistRepository()
        let playlist = try await CreatePlaylistUseCase(playlists: repo)(name: "P", trackIDs: [UUID(), UUID(), UUID()])
        let originalIDs = repo.entries(of: playlist.id).map(\.id)

        try await RenamePlaylistUseCase(playlists: repo)(playlist, to: "Q")
        #expect(repo.playlists.first?.name == "Q")

        let edit = EditPlaylistEntriesUseCase(playlists: repo)
        try await edit.move(fromOffsets: [0], toOffset: 3, in: playlist.id)
        #expect(repo.entries(of: playlist.id).map(\.id) == [originalIDs[1], originalIDs[2], originalIDs[0]])
        try await edit.remove(entryIDs: [originalIDs[2]])
        #expect(repo.entries(of: playlist.id).count == 2)

        try await DeletePlaylistUseCase(playlists: repo)(id: playlist.id)
        #expect(repo.playlists.isEmpty)
    }
}

@MainActor
struct StartPlaybackUseCaseTests {
    @Test func startsFromIndex() {
        let player = FakePlaybackController()
        let tracks = [Track.fixture("a"), Track.fixture("b")]
        StartPlaybackUseCase(playback: player)(tracks, startingAt: 1)
        #expect(player.playCalls == [.init(tracks: tracks, index: 1, shuffled: false)])
    }

    @Test func ignoresEmptyAndInvalidIndex() {
        let player = FakePlaybackController()
        let start = StartPlaybackUseCase(playback: player)
        start([])
        start([.fixture("a")], startingAt: 3)
        start.shuffleAll([])
        #expect(player.playCalls.isEmpty)
    }

    @Test func shuffleAllStartsShuffled() {
        let player = FakePlaybackController()
        StartPlaybackUseCase(playback: player).shuffleAll([.fixture("a"), .fixture("b")])
        #expect(player.playCalls.count == 1)
        #expect(player.playCalls[0].shuffled)
    }
}
