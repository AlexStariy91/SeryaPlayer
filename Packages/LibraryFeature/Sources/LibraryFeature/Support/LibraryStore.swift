import Domain
import Foundation
import Observation

/// Live library state shared by the Library screens: all tracks, derived groups and shelves,
/// playlists and the now-playing track. Derived values are rebuilt once per change, not per render.
@MainActor
@Observable
final class LibraryStore {
    private(set) var tracks: [Track] = []
    private(set) var tracksByID: [Track.ID: Track] = [:]
    private(set) var artists: [TrackGroup] = []
    private(set) var albums: [TrackGroup] = []
    private(set) var recentlyAdded: [Track] = []
    private(set) var recentlyPlayed: [Track] = []
    private(set) var playlists: [Playlist] = []
    private(set) var nowPlayingID: Track.ID?
    /// False until the first track list arrives, so the empty state doesn't flash on launch.
    private(set) var hasLoaded = false

    @ObservationIgnored private var groupsByID: [String: TrackGroup] = [:]
    @ObservationIgnored private let trackRepository: any TrackRepository
    @ObservationIgnored private let playlistRepository: any PlaylistRepository
    @ObservationIgnored private let player: any PlaybackControlling

    init(tracks: any TrackRepository, playlists: any PlaylistRepository, player: any PlaybackControlling) {
        trackRepository = tracks
        playlistRepository = playlists
        self.player = player
    }

    func group(id: String) -> TrackGroup? {
        groupsByID[id]
    }

    func playlist(id: Playlist.ID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    /// Follows the repositories and the player until the calling task is cancelled.
    func observe() async {
        await withDiscardingTaskGroup { group in
            group.addTask { await self.observeTracks() }
            group.addTask { await self.observePlaylists() }
            group.addTask { await self.observePlayer() }
        }
    }

    /// Takes one snapshot of tracks and playlists (tests and snapshot rendering).
    func load() async {
        var tracks = trackRepository.observeTracks(sortedBy: TrackSort()).makeAsyncIterator()
        var playlists = playlistRepository.observePlaylists().makeAsyncIterator()
        if let list = await tracks.next() {
            apply(list)
        }
        if let list = await playlists.next() {
            self.playlists = list
        }
    }

    private func observeTracks() async {
        for await list in trackRepository.observeTracks(sortedBy: TrackSort()) {
            apply(list)
        }
    }

    private func observePlaylists() async {
        for await list in playlistRepository.observePlaylists() {
            playlists = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    private func observePlayer() async {
        for await snapshot in player.snapshots() where snapshot.nowPlaying?.id != nowPlayingID {
            nowPlayingID = snapshot.nowPlaying?.id
        }
    }

    func apply(_ list: [Track]) {
        tracks = list
        tracksByID = Dictionary(list.map { ($0.id, $0) }) { first, _ in first }
        artists = LibraryGrouping.artists(from: list)
        albums = LibraryGrouping.albums(from: list)
        groupsByID = Dictionary((artists + albums).map { ($0.id, $0) }) { first, _ in first }
        recentlyAdded = LibraryGrouping.recentlyAdded(list)
        recentlyPlayed = LibraryGrouping.recentlyPlayed(list)
        hasLoaded = true
    }
}
