import Domain
import Foundation
import Observation

/// All Tracks: the repository-sorted list, the persisted sort and scoped search.
@MainActor
@Observable
final class AllTracksViewModel {
    private(set) var tracks: [Track] = []
    private(set) var sort: TrackSort
    private(set) var hasLoaded = false
    var query = ""
    var scope: SearchScope = .all
    /// `nil` while not searching.
    private(set) var results: [Track]?

    var visibleTracks: [Track] {
        results ?? tracks
    }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ObservationIgnored private let repository: any TrackRepository
    @ObservationIgnored private let settings: any SettingsRepository
    @ObservationIgnored private var index: TrackSearchIndex?
    /// Bumped on every new list, so a search over a stale list is dropped.
    @ObservationIgnored private var generation = 0

    init(tracks: any TrackRepository, settings: any SettingsRepository) {
        repository = tracks
        self.settings = settings
        sort = settings.load().librarySort
    }

    /// Follows the library in the current sort order until cancelled. Restart it when `sort` changes.
    func observe() async {
        for await list in repository.observeTracks(sortedBy: sort) {
            await apply(list)
        }
    }

    /// Takes one snapshot (tests and snapshot rendering).
    func load() async {
        var iterator = repository.observeTracks(sortedBy: sort).makeAsyncIterator()
        if let list = await iterator.next() {
            await apply(list)
        }
    }

    /// Picking the current field again flips the direction. The choice is saved to `AppSettings.librarySort`.
    func setSort(_ field: TrackSort.Field) {
        if sort.field == field {
            sort.ascending.toggle()
        } else {
            // Dates and counters read best newest/most first.
            sort = TrackSort(field: field, ascending: field == .title || field == .artist)
        }
        var saved = settings.load()
        saved.librarySort = sort
        settings.save(saved)
    }

    /// Runs the current query against the loaded list off the main actor. Call after the debounce.
    func search() async {
        guard isSearching else {
            results = nil
            return
        }
        let snapshot = tracks
        let query = query
        let scope = scope
        let existing = index
        let generation = generation
        let (found, built) = await Task.detached(priority: .userInitiated) {
            let index = existing ?? TrackSearchIndex(snapshot)
            return (index.matches(query, scope: scope).map { snapshot[$0] }, index)
        }.value
        // A newer keystroke or list may have arrived while searching.
        guard query == self.query, scope == self.scope, generation == self.generation else { return }
        index = built
        results = found
    }

    private func apply(_ list: [Track]) async {
        tracks = list
        index = nil
        generation += 1
        hasLoaded = true
        if isSearching {
            await search()
        }
    }
}
