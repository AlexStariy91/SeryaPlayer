import Domain
import Foundation
import Observation

/// Live copy of the folder tree, the tracks and the playing track. One store feeds every screen of the
/// tab, so pushing a folder screen does not start new database observations.
@MainActor
@Observable
final class FoldersStore {
    private(set) var folders: [Folder] = [] {
        didSet { rebuildFolderIndex() }
    }

    private(set) var tracks: [Track] = [] {
        didSet { rebuildTrackIndex() }
    }

    private(set) var nowPlayingID: Track.ID?
    private(set) var isLoaded = false

    /// Indexes rebuilt once per observed change; accessors are dictionary lookups.
    @ObservationIgnored private var childrenByParent: [Folder.ID?: [Folder]] = [:]
    @ObservationIgnored private var tracksByFolder: [Folder.ID?: [Track]] = [:]
    @ObservationIgnored private var songCountByFolder: [Folder.ID?: Int] = [:]

    @ObservationIgnored private let folderRepository: any FolderRepository
    @ObservationIgnored private let trackRepository: any TrackRepository
    @ObservationIgnored private let player: any PlaybackControlling
    @ObservationIgnored private var hasFolders = false
    @ObservationIgnored private var hasTracks = false

    init(folders: any FolderRepository, tracks: any TrackRepository, player: any PlaybackControlling) {
        folderRepository = folders
        trackRepository = tracks
        self.player = player
    }

    /// Runs until cancelled.
    func observe() async {
        await withDiscardingTaskGroup { group in
            group.addTask { await self.observeFolders() }
            group.addTask { await self.observeTracks() }
            group.addTask { await self.observePlayer() }
        }
    }

    private func observeFolders() async {
        for await list in folderRepository.observeFolders() {
            folders = list
            hasFolders = true
            updateLoaded()
        }
    }

    private func observeTracks() async {
        for await list in trackRepository.observeTracks(sortedBy: TrackSort(field: .title)) {
            tracks = list
            hasTracks = true
            updateLoaded()
        }
    }

    private func observePlayer() async {
        for await snapshot in player.snapshots() {
            let id = snapshot.nowPlaying?.id
            if id != nowPlayingID {
                nowPlayingID = id
            }
        }
    }

    private func updateLoaded() {
        isLoaded = hasFolders && hasTracks
    }

    func folder(_ id: Folder.ID) -> Folder? {
        folders.first { $0.id == id }
    }

    /// Direct subfolders in manual order (`sortIndex`, then name).
    func subfolders(of parentID: Folder.ID?) -> [Folder] {
        childrenByParent[parentID] ?? []
    }

    /// Tracks stored directly in a folder (or at the library root for `nil`), sorted by title.
    func tracks(in folderID: Folder.ID?) -> [Track] {
        tracksByFolder[folderID] ?? []
    }

    /// Songs in the folder and all its subfolders (`nil` = the whole library).
    func songCount(in folderID: Folder.ID?) -> Int {
        songCountByFolder[folderID] ?? 0
    }

    /// The folder's tracks followed by those of its subfolders, depth first in manual folder order.
    /// This is what Play and Shuffle use.
    func playableTracks(in folderID: Folder.ID?) -> [Track] {
        var result = tracks(in: folderID)
        result.reserveCapacity(songCount(in: folderID))
        for child in subfolders(of: folderID) {
            result += playableTracks(in: child.id)
        }
        return result
    }

    private func rebuildFolderIndex() {
        childrenByParent = Dictionary(grouping: folders, by: \.parentID)
            .mapValues { $0.sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) } }
        rebuildCounts()
    }

    private func rebuildTrackIndex() {
        let sorted = tracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        tracksByFolder = Dictionary(grouping: sorted, by: \.folderID)
        rebuildCounts()
    }

    /// Bottom-up: a folder's count is its own tracks plus its children's counts.
    private func rebuildCounts() {
        var counts: [Folder.ID?: Int] = [:]
        func count(_ id: Folder.ID?) -> Int {
            if let known = counts[id] {
                return known
            }
            let total = (tracksByFolder[id]?.count ?? 0) + (childrenByParent[id] ?? []).reduce(0) { $0 + count($1.id) }
            counts[id] = total
            return total
        }
        _ = count(nil)
        for folder in folders {
            _ = count(folder.id)
        }
        songCountByFolder = counts
    }

    func descendantIDs(of id: Folder.ID) -> Set<Folder.ID> {
        var result: Set<Folder.ID> = []
        var queue = [id]
        while let next = queue.popLast() {
            for child in folders where child.parentID == next && result.insert(child.id).inserted {
                queue.append(child.id)
            }
        }
        return result
    }
}
