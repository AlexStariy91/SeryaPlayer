import Domain
import DomainTestSupport
import Foundation
@testable import LibraryFeature
import Testing

@MainActor
struct LibraryStoreTests {
    @Test func groupsArtistsAndAlbums() async {
        let deps = TestDependencies(tracks: [
            .make("One", artist: "Massive Attack", album: "Mezzanine", trackNumber: 1, artworkKey: "mezz"),
            .make("Two", artist: "massive attack", album: "Mézzanine", trackNumber: 2),
            .make("Solo", artist: "Air", album: "Moon Safari"),
            .make("Loose", artist: "", album: ""),
        ])
        let store = deps.makeContext().store
        await store.load()

        #expect(store.artists.map(\.name) == ["Air", "Massive Attack", ""])
        let massive = store.artists[1]
        #expect(massive.tracks.map(\.title) == ["One", "Two"])
        #expect(massive.albumCount == 1)

        #expect(store.albums.map(\.name) == ["Mezzanine", "Moon Safari", ""])
        #expect(store.albums[0].artworkKey == "mezz")
        #expect(store.group(id: store.albums[0].id)?.tracks.count == 2)
        #expect(Strings.artist("") == "Unknown Artist")
    }

    @Test func shelvesShowNewestAddedAndPlayed() async {
        let deps = TestDependencies(tracks: [
            .make("Old", added: 1, lastPlayed: 50),
            .make("New", added: 9),
            .make("Mid", added: 5, lastPlayed: 80),
        ])
        let store = deps.makeContext().store
        await store.load()
        #expect(store.recentlyAdded.map(\.title) == ["New", "Mid", "Old"])
        #expect(store.recentlyPlayed.map(\.title) == ["Mid", "Old"])
    }

    @Test func shelvesAreCapped() {
        let tracks = (0 ..< 50).map { Track.make("T\($0)", added: Double($0), lastPlayed: Double($0)) }
        #expect(LibraryGrouping.recentlyAdded(tracks).count == LibraryGrouping.shelfLimit)
        #expect(LibraryGrouping.recentlyPlayed(tracks).first?.title == "T49")
    }

    @Test func followsRepositoryChanges() async throws {
        let deps = TestDependencies(tracks: [.make("A")])
        let store = deps.makeContext().store
        let observing = Task { await store.observe() }
        defer { observing.cancel() }
        #expect(await eventually { store.tracks.count == 1 })
        try await deps.tracks.add([.make("B", artist: "Other")])
        #expect(await eventually { store.artists.count == 2 })
        try await deps.playlists.create(Playlist(name: "Mix"))
        #expect(await eventually { store.playlists.map(\.name) == ["Mix"] })
    }

    @Test func groupsTenThousandTracks() async {
        let tracks = (0 ..< 10000).map { Track.make("Song \($0)", artist: "Artist \($0 % 300)", album: "Album \($0 % 900)") }
        let store = TestDependencies(tracks: tracks).makeContext().store
        let elapsed = await ContinuousClock().measure { await store.load() }
        #expect(store.artists.count == 300)
        #expect(store.albums.count == 900)
        #expect(elapsed < .seconds(2), "grouping took \(elapsed)")
    }
}
