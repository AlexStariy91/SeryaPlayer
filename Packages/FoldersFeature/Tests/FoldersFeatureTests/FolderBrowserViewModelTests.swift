import Domain
import DomainTestSupport
@testable import FoldersFeature
import Testing

@MainActor
struct FolderBrowserViewModelTests {
    private let rock = Folder(name: "Rock", sortIndex: 0)
    private let jazz = Folder(name: "Jazz", sortIndex: 1)

    private struct Fixture {
        let deps: TestDependencies
        let context: FoldersContext
        let live: Folder
    }

    /// Root: `Loose`. Rock: `Anthem`. Rock/Live: `Encore`. Jazz: empty.
    private func makeFixture() async -> Fixture {
        let live = Folder(name: "Live", parentID: rock.id)
        let deps = TestDependencies(
            folders: [rock, jazz, live],
            tracks: [
                .fixture("Loose"),
                .fixture("Anthem", folderID: rock.id),
                .fixture("Encore", folderID: live.id),
            ]
        )
        return await Fixture(deps: deps, context: deps.loadedContext(), live: live)
    }

    @Test func rootListsTopLevelFoldersAndRootTracks() async {
        let fixture = await makeFixture()
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        #expect(viewModel.subfolders.map(\.name) == ["Rock", "Jazz"])
        #expect(viewModel.tracks.map(\.title) == ["Loose"])
        #expect(viewModel.songCount(in: rock) == 2)
    }

    @Test func folderScreenListsItsOwnContent() async {
        let fixture = await makeFixture()
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: rock.id, context: context)
        #expect(viewModel.title == "Rock")
        #expect(viewModel.subfolders.map(\.name) == ["Live"])
        #expect(viewModel.tracks.map(\.title) == ["Anthem"])
    }

    @Test func playAllIncludesSubfoldersDepthFirst() async {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        FolderBrowserViewModel(folderID: rock.id, context: context).playAll(shuffled: false)
        #expect(deps.playback.playCalls.first?.tracks.map(\.title) == ["Anthem", "Encore"])
        #expect(deps.playback.playCalls.first?.shuffled == false)
    }

    @Test func shuffleStartsShuffledPlayback() async {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        FolderBrowserViewModel(folderID: rock.id, context: context).playAll(shuffled: true)
        #expect(deps.playback.playCalls.first?.shuffled == true)
        #expect(deps.playback.playCalls.first?.tracks.count == 2)
    }

    @Test func tappingASongPlaysTheScreenList() async throws {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        try viewModel.play(#require(viewModel.tracks.first))
        #expect(deps.playback.playCalls.first?.tracks.map(\.title) == ["Loose"])
        #expect(deps.playback.playCalls.first?.index == 0)
    }

    @Test func createFolderUnderCurrentFolder() async throws {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: jazz.id, context: context)
        viewModel.beginCreate()
        viewModel.nameText = "  Bebop "
        await viewModel.commitName(for: .create)
        let created = try await deps.folders.folders().first { $0.name == "Bebop" }
        #expect(created?.parentID == jazz.id)
    }

    @Test func emptyNameShowsError() async {
        let fixture = await makeFixture()
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        viewModel.beginCreate()
        await viewModel.commitName(for: .create)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func renameFolder() async throws {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        viewModel.beginRename(jazz)
        #expect(viewModel.nameText == "Jazz")
        viewModel.nameText = "Blues"
        await viewModel.commitName(for: .rename(jazz.id))
        #expect(try await deps.folders.folders().contains { $0.name == "Blues" })
    }

    @Test func deletingEmptyFolderNeedsNoConfirmation() async throws {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        await viewModel.requestDelete(items: [.folder(jazz.id)])
        #expect(viewModel.pendingDeletion == nil)
        #expect(try await deps.folders.folders().contains { $0.id == jazz.id } == false)
    }

    @Test func deletingFolderWithSongsAsksAndKeepsThemOnRequest() async throws {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        await viewModel.requestDelete(items: [.folder(rock.id)])
        let request = try #require(viewModel.pendingDeletion)
        #expect(request.folderTrackCount == 2)
        await viewModel.performDeletion(request, policy: .moveTracksToRoot)
        let tracks = try await deps.tracks.tracks(inFolder: nil, includeSubfolders: false)
        #expect(Set(tracks.map(\.title)) == ["Loose", "Anthem", "Encore"])
        #expect(try await deps.folders.folders().map(\.name) == ["Jazz"])
    }

    @Test func deletingFolderWithSongsCanDeleteThem() async throws {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        await viewModel.requestDelete(items: [.folder(rock.id)])
        try await viewModel.performDeletion(#require(viewModel.pendingDeletion), policy: .deleteTracks)
        let remaining = try await deps.tracks.tracks(inFolder: nil, includeSubfolders: true)
        #expect(remaining.map(\.title) == ["Loose"])
    }

    @Test func batchDeleteOfSelectedSongsAlwaysAsks() async throws {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        let loose = try #require(viewModel.tracks.first)
        await viewModel.requestDelete(items: [.track(loose.id)])
        let request = try #require(viewModel.pendingDeletion)
        #expect(request.folderTrackCount == 0)
        await viewModel.performDeletion(request, policy: .moveTracksToRoot)
        #expect(try await deps.tracks.tracks(inFolder: nil, includeSubfolders: false).isEmpty)
    }

    @Test func moveTracksAndFoldersTogether() async throws {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        let loose = try #require(viewModel.tracks.first)
        await viewModel.move([.track(loose.id), .folder(rock.id)], to: jazz.id)
        #expect(try await deps.folders.folders().first { $0.id == rock.id }?.parentID == jazz.id)
        #expect(try await deps.tracks.tracks(ids: [loose.id]).first?.folderID == jazz.id)
    }

    @Test func movingFolderIntoItsDescendantReportsError() async {
        let fixture = await makeFixture()
        let context = fixture.context
        let live = fixture.live
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        await viewModel.move([.folder(rock.id)], to: live.id)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func pickerExcludesMovedFoldersAndTheirSubfolders() async {
        let fixture = await makeFixture()
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        let names = viewModel.destinations(for: [.folder(rock.id)]).map(\.folder.name)
        #expect(names == ["Jazz"])
        let all = viewModel.destinations(for: [.track(.init())])
        #expect(all.map(\.folder.name) == ["Rock", "Live", "Jazz"])
        #expect(all.map(\.depth) == [0, 1, 0])
    }

    @Test func dragReorderPersistsSortIndex() async throws {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = fixture.context
        let viewModel = FolderBrowserViewModel(folderID: nil, context: context)
        await viewModel.moveFolders(fromOffsets: [1], toOffset: 0)
        let order = try await deps.folders.folders().filter { $0.parentID == nil }.sorted { $0.sortIndex < $1.sortIndex }.map(\.name)
        #expect(order == ["Jazz", "Rock"])
    }

    @Test func deletedFolderScreenIsMissing() async {
        let fixture = await makeFixture()
        let deps = fixture.deps
        let context = await deps.loadedContext()
        let viewModel = FolderBrowserViewModel(folderID: .init(), context: context)
        #expect(viewModel.isMissing)
    }
}
