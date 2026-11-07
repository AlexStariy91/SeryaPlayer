import DesignSystem
import Domain
import Foundation
import Observation

/// Live library state shared by the Library screens: all tracks, derived groups and shelves,
/// playlists and the now-playing track. Derived values are rebuilt once per change, not per render, and off the
/// main actor. A change of play statistics only (a track started) refreshes Recently Played and nothing else, so
/// the big lists are not re-rendered on every track change. Their tracks may carry older play statistics until the
/// next catalog change; nothing in them shows those.
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
    private(set) var isPlaying = false
    /// False until the first track list arrives, so the empty state doesn't flash on launch.
    private(set) var hasLoaded = false

    @ObservationIgnored private var groupsByID: [String: TrackGroup] = [:]
    /// How many times the catalog (tracks, groups, Recently Added) was rebuilt. For tests.
    @ObservationIgnored private(set) var catalogRebuildCount = 0
    @ObservationIgnored private let trackRepository: any TrackRepository
    @ObservationIgnored private let playlistRepository: any PlaylistRepository
    @ObservationIgnored private let player: any PlaybackControlling
    /// Levels for the playing row's bars. Built once, so rows passing it stay equal between renders.
    @ObservationIgnored let rowLevels: SpectrumLevelsSource

    init(
        tracks: any TrackRepository,
        playlists: any PlaylistRepository,
        player: any PlaybackControlling,
        spectrum: any AudioSpectrumProviding
    ) {
        trackRepository = tracks
        playlistRepository = playlists
        self.player = player
        rowLevels = { spectrum.spectrum() }
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
            await apply(list)
        }
        if let list = await playlists.next() {
            self.playlists = list
        }
    }

    private func observeTracks() async {
        for await list in trackRepository.observeTracks(sortedBy: TrackSort()) {
            await apply(list)
        }
    }

    private func observePlaylists() async {
        for await list in playlistRepository.observePlaylists() {
            playlists = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    private func observePlayer() async {
        for await snapshot in player.snapshots() {
            if snapshot.nowPlaying?.id != nowPlayingID {
                nowPlayingID = snapshot.nowPlaying?.id
            }
            if snapshot.isPlaying != isPlaying {
                isPlaying = snapshot.isPlaying
            }
        }
    }

    /// The row indicator for `id`: only the current track has one.
    func nowPlaying(_ id: Track.ID) -> TrackRow.NowPlaying? {
        guard id == nowPlayingID else { return nil }
        return isPlaying ? .playing : .paused
    }

    func apply(_ list: [Track]) async {
        let current = hasLoaded ? tracks : nil
        let update = await Task.detached(priority: .userInitiated) {
            LibraryUpdate(list, replacing: current)
        }.value
        switch update {
        case let .catalog(catalog):
            tracks = catalog.tracks
            tracksByID = catalog.tracksByID
            artists = catalog.artists
            albums = catalog.albums
            groupsByID = catalog.groupsByID
            recentlyAdded = catalog.recentlyAdded
            if catalog.recentlyPlayed != recentlyPlayed {
                recentlyPlayed = catalog.recentlyPlayed
            }
            catalogRebuildCount += 1
        case let .playStatistics(played):
            if played != recentlyPlayed {
                recentlyPlayed = played
            }
        }
        if !hasLoaded {
            hasLoaded = true
        }
    }
}

/// What a new track list changes in the store. Built off the main actor.
enum LibraryUpdate {
    struct Catalog {
        var tracks: [Track]
        var tracksByID: [Track.ID: Track]
        var artists: [TrackGroup]
        var albums: [TrackGroup]
        var groupsByID: [String: TrackGroup]
        var recentlyAdded: [Track]
        var recentlyPlayed: [Track]
    }

    /// Tracks, groups or Recently Added changed: everything is rebuilt.
    case catalog(Catalog)
    /// Only play statistics changed: just the new Recently Played shelf.
    case playStatistics(recentlyPlayed: [Track])

    /// - Parameter current: the list the store shows now, or `nil` before the first one.
    init(_ list: [Track], replacing current: [Track]?) {
        if let current, list.hasSameCatalogData(as: current) {
            self = .playStatistics(recentlyPlayed: LibraryGrouping.recentlyPlayed(list))
            return
        }
        let artists = LibraryGrouping.artists(from: list)
        let albums = LibraryGrouping.albums(from: list)
        self = .catalog(Catalog(
            tracks: list,
            tracksByID: Dictionary(list.map { ($0.id, $0) }) { first, _ in first },
            artists: artists,
            albums: albums,
            groupsByID: Dictionary((artists + albums).map { ($0.id, $0) }) { first, _ in first },
            recentlyAdded: LibraryGrouping.recentlyAdded(list),
            recentlyPlayed: LibraryGrouping.recentlyPlayed(list)
        ))
    }
}
