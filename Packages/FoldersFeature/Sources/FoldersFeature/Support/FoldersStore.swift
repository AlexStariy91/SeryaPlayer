import Domain
import Foundation
import Observation

/// Live copy of the folder tree, the tracks and the playing track. One store feeds every screen of the
/// tab, so pushing a folder screen does not start new database observations.
@MainActor
@Observable
final class FoldersStore {
    private(set) var folders: [Folder] = []
    private(set) var tracks: [Track] = []
    private(set) var nowPlayingID: Track.ID?
    private(set) var isLoaded = false

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
            let id = snapshot.isPlaying ? snapshot.nowPlaying?.id : nil
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
        folders.filter { $0.parentID == parentID }.sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
    }

    /// Tracks stored directly in a folder (or at the library root for `nil`), sorted by title.
    func tracks(in folderID: Folder.ID?) -> [Track] {
        tracks.filter { $0.folderID == folderID }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// The folder's tracks followed by those of its subfolders, depth first in manual folder order.
    /// This is what Play, Shuffle and the song count of a folder row use.
    func playableTracks(in folderID: Folder.ID?) -> [Track] {
        var result = tracks(in: folderID)
        for child in subfolders(of: folderID) {
            result += playableTracks(in: child.id)
        }
        return result
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
