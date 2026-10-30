import Domain
import DomainTestSupport
import Foundation
@testable import LibraryFeature
import Testing

@MainActor
struct PlaylistTests {
    @Test func createRenameDelete() async throws {
        let deps = TestDependencies()
        let viewModel = PlaylistsViewModel(playlists: deps.playlists)
        let created = try #require(await viewModel.create(named: "  Road Trip "))
        #expect(deps.playlists.playlists.map(\.name) == ["Road Trip"])

        await viewModel.rename(created, to: "Drive")
        #expect(deps.playlists.playlists.map(\.name) == ["Drive"])

        await viewModel.create(named: "   ")
        #expect(viewModel.isShowingError)
        #expect(viewModel.errorMessage == "The name can't be empty.")
        #expect(deps.playlists.playlists.count == 1)

        await viewModel.delete(created)
        #expect(deps.playlists.playlists.isEmpty)
    }

    private struct Fixture {
        let deps: TestDependencies
        let context: LibraryContext
        let viewModel: PlaylistDetailViewModel
    }

    private func makePlaylist(_ titles: [String]) async throws -> Fixture {
        let tracks = titles.enumerated().map { Track.make($1, artworkKey: "art\($0)") }
        let deps = TestDependencies(tracks: tracks)
        let playlist = Playlist(name: "Mix")
        try await deps.playlists.create(playlist)
        try await deps.playlists.append(trackIDs: tracks.map(\.id), to: playlist.id)
        let context = deps.makeContext()
        await context.store.load()
        let viewModel = PlaylistDetailViewModel(playlistID: playlist.id, playlists: deps.playlists, store: context.store)
        await viewModel.load()
        return Fixture(deps: deps, context: context, viewModel: viewModel)
    }

    @Test func reorderAndRemoveEntries() async throws {
        let fixture = try await makePlaylist(["A", "B", "C", "D"])
        let (deps, viewModel) = (fixture.deps, fixture.viewModel)
        #expect(viewModel.tracks.map(\.title) == ["A", "B", "C", "D"])

        await viewModel.move(fromOffsets: [0], toOffset: 3)
        #expect(viewModel.tracks.map(\.title) == ["B", "C", "A", "D"])
        await viewModel.load()
        #expect(viewModel.tracks.map(\.title) == ["B", "C", "A", "D"])

        await viewModel.remove(atOffsets: [1])
        await viewModel.load()
        #expect(viewModel.tracks.map(\.title) == ["B", "A", "D"])
        #expect(deps.playlists.entries(of: viewModel.playlistID).map(\.sortIndex) == [0, 1, 2])
    }

    @Test func appendAllowsDuplicates() async throws {
        let fixture = try await makePlaylist(["A", "B"])
        let (deps, viewModel) = (fixture.deps, fixture.viewModel)
        let first = try #require(viewModel.tracks.first)
        await viewModel.append([first.id])
        await viewModel.load()
        #expect(viewModel.tracks.map(\.title) == ["A", "B", "A"])
        #expect(deps.playlists.entries(of: viewModel.playlistID).count == 3)
    }

    @Test func playAndShuffleUseThePlaylistOrder() async throws {
        let fixture = try await makePlaylist(["A", "B", "C"])
        let (deps, context, viewModel) = (fixture.deps, fixture.context, fixture.viewModel)
        context.startPlayback(viewModel.tracks)
        context.startPlayback.shuffleAll(viewModel.tracks)
        #expect(deps.spy.plays.first == SpyPlayer.Play(titles: ["A", "B", "C"], index: 0, shuffled: false))
        #expect(deps.spy.plays.last?.shuffled == true)
    }

    @Test func coverUsesFirstFourDistinctArtworks() async throws {
        let fixture = try await makePlaylist(["A", "B", "C", "D", "E"])
        let (context, viewModel) = (fixture.context, fixture.viewModel)
        #expect(viewModel.coverKeys == ["art0", "art1", "art2", "art3"])
        let entries = [PlaylistEntry(trackID: viewModel.tracks[0].id, sortIndex: 0), PlaylistEntry(trackID: viewModel.tracks[0].id, sortIndex: 1)]
        #expect(PlaylistCover.keys(for: entries, tracksByID: context.store.tracksByID) == ["art0"])
    }
}
