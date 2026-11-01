import Domain
import Foundation
import Observation

/// A delete the user still has to confirm.
struct DeletionRequest: Equatable {
    var folderIDs: Set<Folder.ID>
    var trackIDs: Set<Track.ID>
    var title: String
    /// Songs inside the folders (subfolders included) that the policy decides about.
    var folderTrackCount: Int
}

struct SearchKey: Hashable {
    let query: String
    let revision: Int
}

enum NamePrompt: Equatable {
    case create
    case rename(Folder.ID)
}

/// One screen of the tree: the library root (`folderID == nil`) or a folder.
@MainActor
@Observable
final class FolderBrowserViewModel {
    let folderID: Folder.ID?
    private let context: FoldersContext

    /// Select mode. Ending it drops the selection; a finished batch delete or move ends it, like Apple's apps.
    var isEditing = false {
        didSet {
            if !isEditing {
                selection = []
            }
        }
    }

    var selection: Set<FolderItem> = []
    var namePrompt: NamePrompt?
    var nameText = ""
    var pendingDeletion: DeletionRequest?
    /// Items waiting for a destination in the move picker.
    var movingItems: Set<FolderItem>?
    var errorMessage: String?
    var searchQuery = ""
    /// Results for the last searched query; `nil` while not searching.
    private(set) var searchResults: FolderSearchResults?

    init(folderID: Folder.ID?, context: FoldersContext) {
        self.folderID = folderID
        self.context = context
    }

    private var store: FoldersStore {
        context.store
    }

    // MARK: - Content

    var isLoaded: Bool {
        store.isLoaded
    }

    /// A folder that was deleted (or moved away from under us) while its screen was open.
    var isMissing: Bool {
        guard let folderID else { return false }
        return store.isLoaded && store.folder(folderID) == nil
    }

    var title: String {
        folderID.flatMap { store.folder($0)?.name } ?? String(localized: "Folders", bundle: .module)
    }

    var subfolders: [Folder] {
        store.subfolders(of: folderID)
    }

    var tracks: [Track] {
        store.tracks(in: folderID)
    }

    var isEmpty: Bool {
        subfolders.isEmpty && tracks.isEmpty
    }

    /// Rows read the now-playing state from here themselves, so a track change re-renders the rows on
    /// screen instead of re-running this screen's body (and re-diffing the whole list).
    var playback: FoldersStore {
        store
    }

    /// Songs in the folder and all its subfolders.
    func songCount(in folder: Folder) -> Int {
        store.songCount(in: folder.id)
    }

    var artwork: ArtworkResolver {
        context.artwork
    }

    // MARK: - Search

    var isSearching: Bool {
        !trimmedQuery.isEmpty
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What the search task depends on: a change in the library re-runs the search.
    var searchKey: SearchKey {
        SearchKey(query: trimmedQuery, revision: store.revision)
    }

    /// Searches this folder and everything below it (the whole library at the root), off the main actor.
    func search() async {
        let query = trimmedQuery
        guard !query.isEmpty else {
            searchResults = nil
            return
        }
        let results = await FolderSearch.run(query, in: folderID, folders: store.folders, tracks: store.tracks)
        guard !Task.isCancelled else { return }
        searchResults = results
    }

    /// Tapping a found song plays the found songs, starting with it.
    func playSearchResult(_ track: Track) {
        guard let list = searchResults?.tracks, let index = list.firstIndex(of: track) else { return }
        context.startPlayback.playOrToggle(list, at: index)
    }

    // MARK: - Playback

    /// Tapping a song plays the songs listed on this screen, starting with the tapped one.
    func play(_ track: Track) {
        let list = tracks
        guard let index = list.firstIndex(of: track) else { return }
        context.startPlayback.playOrToggle(list, at: index)
    }

    /// A folder row's Play / Shuffle: the folder is played as the tree below it, depth first.
    func play(folder id: Folder.ID?, shuffled: Bool) {
        let list = store.playableTracks(in: id)
        if shuffled {
            context.startPlayback.shuffleAll(list)
        } else {
            context.startPlayback(list)
        }
    }

    // MARK: - Create / rename

    func beginCreate() {
        nameText = ""
        namePrompt = .create
    }

    func beginRename(_ folder: Folder) {
        nameText = folder.name
        namePrompt = .rename(folder.id)
    }

    /// `prompt` is passed in by the alert: it is dismissed (and the stored prompt cleared) before this runs.
    func commitName(for prompt: NamePrompt) async {
        namePrompt = nil
        await perform {
            switch prompt {
            case .create:
                _ = try await self.context.createFolder(name: self.nameText, parentID: self.folderID)
            case let .rename(id):
                try await self.context.renameFolder(id: id, to: self.nameText)
            }
        }
    }

    // MARK: - Delete

    /// Empty folders go straight away; anything holding songs asks first.
    func requestDelete(items: Set<FolderItem>) async {
        let (folderIDs, trackIDs) = split(items)
        guard !folderIDs.isEmpty || !trackIDs.isEmpty else { return }
        // Songs inside selected folders and also selected themselves are counted once.
        let inside = Set(folderIDs.flatMap { store.playableTracks(in: $0).map(\.id) })
        let request = DeletionRequest(
            folderIDs: folderIDs,
            trackIDs: trackIDs,
            title: deletionTitle(folderIDs: folderIDs, trackCount: trackIDs.count),
            folderTrackCount: inside.subtracting(trackIDs).count
        )
        if trackIDs.isEmpty, request.folderTrackCount == 0 {
            await performDeletion(request, policy: .moveTracksToRoot)
        } else {
            pendingDeletion = request
        }
    }

    func cancelDeletion() {
        pendingDeletion = nil
    }

    /// `policy` decides about the songs inside the folders; songs that were selected themselves are always deleted.
    /// The request is passed in by the confirmation dialog: it is dismissed (and the stored request cleared) before this runs.
    func performDeletion(_ request: DeletionRequest, policy: FolderDeletionPolicy) async {
        pendingDeletion = nil
        await perform {
            let doomed = self.store.tracks.filter { request.trackIDs.contains($0.id) }
            try await self.context.deleteTracks(doomed)
            for id in self.topLevel(request.folderIDs) {
                try await self.context.deleteFolder(id: id, policy: policy)
            }
        }
        isEditing = false
    }

    // MARK: - Move

    func beginMove(_ items: Set<FolderItem>) {
        guard !items.isEmpty else { return }
        movingItems = items
    }

    /// Folders the picker offers: everything except the moved folders and their subfolders.
    func destinations(for items: Set<FolderItem>) -> [FolderTreeRow] {
        let (folderIDs, _) = split(items)
        return FolderTreeRow.flatten(store.folders, excluding: folderIDs)
    }

    /// Whether every moved item already lives in `destination`.
    func isCurrent(_ destination: Folder.ID?, for items: Set<FolderItem>) -> Bool {
        let (folderIDs, trackIDs) = split(items)
        let folderParents = folderIDs.compactMap { store.folder($0) }.map(\.parentID)
        let trackParents = store.tracks.filter { trackIDs.contains($0.id) }.map(\.folderID)
        let all = folderParents + trackParents
        return !all.isEmpty && all.allSatisfy { $0 == destination }
    }

    func move(_ items: Set<FolderItem>, to destination: Folder.ID?) async {
        movingItems = nil
        let (folderIDs, trackIDs) = split(items)
        await perform {
            try await self.context.moveTracks(Array(trackIDs), toFolder: destination)
            for id in self.topLevel(folderIDs) {
                try await self.context.moveFolder(id: id, toParent: destination)
            }
        }
        isEditing = false
    }

    // MARK: - Reorder

    func moveFolders(fromOffsets source: IndexSet, toOffset destination: Int) async {
        var ids = subfolders.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        await perform { try await self.context.reorderFolders(orderedIDs: ids) }
    }

    // MARK: - Helpers

    private func split(_ items: Set<FolderItem>) -> (folders: Set<Folder.ID>, tracks: Set<Track.ID>) {
        var folderIDs: Set<Folder.ID> = []
        var trackIDs: Set<Track.ID> = []
        for item in items {
            switch item {
            case let .folder(id): folderIDs.insert(id)
            case let .track(id): trackIDs.insert(id)
            }
        }
        return (folderIDs, trackIDs)
    }

    /// Drops folders whose ancestor is in the set too: the ancestor's operation already covers them.
    private func topLevel(_ ids: Set<Folder.ID>) -> [Folder.ID] {
        let covered = ids.reduce(into: Set<Folder.ID>()) { $0.formUnion(store.descendantIDs(of: $1)) }
        return ids.filter { !covered.contains($0) }.sorted { $0.uuidString < $1.uuidString }
    }

    private func deletionTitle(folderIDs: Set<Folder.ID>, trackCount: Int) -> String {
        if folderIDs.count == 1, trackCount == 0, let name = folderIDs.first.flatMap({ store.folder($0)?.name }) {
            return String(localized: "Delete “\(name)”?", bundle: .module)
        }
        if folderIDs.isEmpty {
            return String(localized: "Delete \(trackCount) songs?", bundle: .module)
        }
        return String(localized: "Delete \(folderIDs.count + trackCount) items?", bundle: .module)
    }

    private func perform(_ work: () async throws -> Void) async {
        do {
            try await work()
        } catch let error as DomainError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func message(for error: DomainError) -> String {
        switch error {
        case .emptyName: String(localized: "Enter a name for the folder.", bundle: .module)
        case .folderCycle: String(localized: "A folder can’t be moved into itself or one of its subfolders.", bundle: .module)
        case .folderNotFound, .playlistNotFound: String(localized: "That folder no longer exists.", bundle: .module)
        }
    }
}
