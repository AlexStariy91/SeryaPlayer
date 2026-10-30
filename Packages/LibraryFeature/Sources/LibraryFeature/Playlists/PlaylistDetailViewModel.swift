import Domain
import Foundation
import Observation

/// One playlist: its entries resolved to tracks, reordering, removal and adding tracks.
@MainActor
@Observable
final class PlaylistDetailViewModel {
    struct Row: Identifiable, Equatable {
        let entry: PlaylistEntry
        let track: Track

        var id: PlaylistEntry.ID {
            entry.id
        }
    }

    let playlistID: Playlist.ID
    private(set) var entries: [PlaylistEntry] = []
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    var isShowingError = false

    @ObservationIgnored private let repository: any PlaylistRepository
    @ObservationIgnored private let store: LibraryStore
    @ObservationIgnored private let edit: EditPlaylistEntriesUseCase
    @ObservationIgnored private let add: AddTracksToPlaylistUseCase

    init(playlistID: Playlist.ID, playlists: any PlaylistRepository, store: LibraryStore) {
        self.playlistID = playlistID
        repository = playlists
        self.store = store
        edit = EditPlaylistEntriesUseCase(playlists: playlists)
        add = AddTracksToPlaylistUseCase(playlists: playlists)
    }

    /// Entries whose track still exists, in playlist order.
    var rows: [Row] {
        let byID = store.tracksByID
        return entries.compactMap { entry in byID[entry.trackID].map { Row(entry: entry, track: $0) } }
    }

    var tracks: [Track] {
        rows.map(\.track)
    }

    var coverKeys: [String] {
        PlaylistCover.keys(for: entries, tracksByID: store.tracksByID)
    }

    func observe() async {
        for await list in repository.observeEntries(of: playlistID) {
            apply(list)
        }
    }

    func load() async {
        var iterator = repository.observeEntries(of: playlistID).makeAsyncIterator()
        if let list = await iterator.next() {
            apply(list)
        }
    }

    /// `source` and `destination` are offsets in `rows`; they are mapped to entry offsets,
    /// which differ when an entry's track is missing.
    func move(fromOffsets source: IndexSet, toOffset destination: Int) async {
        let visible = rows
        let entryIndex = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($1.id, $0) })
        let from = IndexSet(source.compactMap { visible.indices.contains($0) ? entryIndex[visible[$0].id] : nil })
        let to = destination < visible.count ? entryIndex[visible[destination].id] ?? entries.count : entries.count
        // Reorder locally first so the list doesn't jump back while the repository saves.
        entries.move(fromOffsets: from, toOffset: to)
        await perform { try await self.edit.move(fromOffsets: from, toOffset: to, in: self.playlistID) }
    }

    func remove(atOffsets offsets: IndexSet) async {
        let visible = rows
        await remove(entryIDs: offsets.compactMap { visible.indices.contains($0) ? visible[$0].id : nil })
    }

    func remove(entryIDs ids: [PlaylistEntry.ID]) async {
        entries.removeAll { ids.contains($0.id) }
        await perform { try await self.edit.remove(entryIDs: ids) }
    }

    func append(_ trackIDs: [Track.ID]) async {
        await perform { try await self.add(trackIDs: trackIDs, to: self.playlistID) }
    }

    private func apply(_ list: [PlaylistEntry]) {
        entries = list.sorted { $0.sortIndex < $1.sortIndex }
        hasLoaded = true
    }

    private func perform(_ work: () async throws -> Void) async {
        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }
}
