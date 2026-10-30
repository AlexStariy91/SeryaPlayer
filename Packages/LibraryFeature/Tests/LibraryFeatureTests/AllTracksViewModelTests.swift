import Domain
import DomainTestSupport
import Foundation
@testable import LibraryFeature
import Testing

@MainActor
struct AllTracksViewModelTests {
    private let library = [
        Track.make("Bravo", artist: "Zoë", album: "Été", duration: 300, added: 2, playCount: 5),
        Track.make("alpha", artist: "Björk", album: "Post", duration: 100, added: 3, playCount: 1),
        Track.make("Charlie", artist: "Air", album: "Moon Safari", duration: 200, added: 1, playCount: 9),
    ]

    @Test func loadsInPersistedSortOrder() async {
        let deps = TestDependencies(tracks: library, settings: AppSettings(librarySort: TrackSort(field: .duration, ascending: false)))
        let viewModel = AllTracksViewModel(tracks: deps.tracks, settings: deps.settings)
        await viewModel.load()
        #expect(viewModel.sort == TrackSort(field: .duration, ascending: false))
        #expect(viewModel.tracks.map(\.title) == ["Bravo", "Charlie", "alpha"])
    }

    @Test(arguments: [
        (TrackSort.Field.title, ["alpha", "Bravo", "Charlie"]),
        (.artist, ["Charlie", "alpha", "Bravo"]),
        (.dateAdded, ["alpha", "Bravo", "Charlie"]),
        (.duration, ["Bravo", "Charlie", "alpha"]),
        (.playCount, ["Charlie", "Bravo", "alpha"]),
    ])
    func sortsByEachFieldAndPersists(field: TrackSort.Field, expected: [String]) async {
        let deps = TestDependencies(tracks: library, settings: AppSettings(librarySort: TrackSort(field: field == .title ? .artist : .title)))
        let viewModel = AllTracksViewModel(tracks: deps.tracks, settings: deps.settings)
        viewModel.setSort(field)
        await viewModel.load()
        #expect(viewModel.tracks.map(\.title) == expected)
        #expect(deps.settings.load().librarySort == viewModel.sort)
    }

    @Test func choosingTheSameFieldFlipsDirection() {
        let deps = TestDependencies()
        let viewModel = AllTracksViewModel(tracks: deps.tracks, settings: deps.settings)
        #expect(viewModel.sort == TrackSort(field: .title, ascending: true))
        viewModel.setSort(.title)
        #expect(viewModel.sort == TrackSort(field: .title, ascending: false))
        #expect(deps.settings.load().librarySort.ascending == false)
    }

    @Test func searchIsCaseAndDiacriticInsensitive() async {
        let deps = TestDependencies(tracks: library)
        let viewModel = AllTracksViewModel(tracks: deps.tracks, settings: deps.settings)
        await viewModel.load()
        viewModel.query = "BJORK"
        await viewModel.search()
        #expect(viewModel.visibleTracks.map(\.title) == ["alpha"])
        viewModel.query = "ete"
        await viewModel.search()
        #expect(viewModel.visibleTracks.map(\.title) == ["Bravo"])
    }

    @Test func scopesNarrowTheSearch() async {
        let tracks = [
            Track.make("Moon", artist: "A", album: "X"),
            Track.make("Sun", artist: "Moon", album: "Y"),
            Track.make("Star", artist: "B", album: "Moonlight")
        ]
        let deps = TestDependencies(tracks: tracks)
        let viewModel = AllTracksViewModel(tracks: deps.tracks, settings: deps.settings)
        await viewModel.load()
        viewModel.query = "moon"
        for (scope, expected) in [(SearchScope.all, ["Moon", "Star", "Sun"]), (.title, ["Moon"]), (.artist, ["Sun"]), (.album, ["Star"])] {
            viewModel.scope = scope
            await viewModel.search()
            #expect(viewModel.visibleTracks.map(\.title) == expected, "scope \(scope)")
        }
    }

    @Test func clearingTheQueryShowsTheFullList() async {
        let deps = TestDependencies(tracks: library)
        let viewModel = AllTracksViewModel(tracks: deps.tracks, settings: deps.settings)
        await viewModel.load()
        viewModel.query = "zzz"
        await viewModel.search()
        #expect(viewModel.visibleTracks.isEmpty)
        viewModel.query = "  "
        await viewModel.search()
        #expect(viewModel.results == nil)
        #expect(viewModel.visibleTracks.count == 3)
    }

    @Test func searchFollowsLibraryChanges() async throws {
        let deps = TestDependencies(tracks: library)
        let viewModel = AllTracksViewModel(tracks: deps.tracks, settings: deps.settings)
        let observing = Task { await viewModel.observe() }
        defer { observing.cancel() }
        #expect(await eventually { viewModel.tracks.count == 3 })
        viewModel.query = "new"
        await viewModel.search()
        try await deps.tracks.add([.make("Brand New")])
        #expect(await eventually { viewModel.visibleTracks.map(\.title) == ["Brand New"] })
    }

    @Test func handlesTenThousandTracksWithFastSearch() async {
        let tracks = (0 ..< 10000).map { Track.make("Song \($0)", artist: "Artist \($0 % 300)", album: "Album \($0 % 900)") }
        let deps = TestDependencies(tracks: tracks)
        let viewModel = AllTracksViewModel(tracks: deps.tracks, settings: deps.settings)
        await viewModel.load()
        #expect(viewModel.tracks.count == 10000)

        viewModel.query = "artist 12"
        await viewModel.search()
        // "Artist 12" plus "Artist 120"…"Artist 129" → 11 artists × ~33 tracks each.
        #expect(viewModel.visibleTracks.count > 300)
        viewModel.scope = .title
        viewModel.query = "song 99"
        await viewModel.search()
        #expect(viewModel.visibleTracks.count == 111)

        // The scan itself, timed without main-actor hops (other suites render snapshots in parallel).
        let clock = ContinuousClock()
        var index: TrackSearchIndex?
        let build = clock.measure { index = TrackSearchIndex(viewModel.tracks) }
        let scan = clock.measure { _ = index?.matches("artist 12", scope: .all) }
        // Generous bounds for CI simulators; locally these are a few milliseconds.
        #expect(build < .seconds(1), "building the index took \(build)")
        #expect(scan < .milliseconds(500), "one search took \(scan)")
    }
}
