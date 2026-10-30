import Domain
import Foundation

public final class InMemoryFolderRepository: FolderRepository {
    private let box: ObservableBox<[Folder]>

    public init(folders: [Folder] = []) {
        box = ObservableBox(folders)
    }

    public var snapshot: [Folder] {
        box.value
    }

    public func observeFolders() -> AsyncStream<[Folder]> {
        box.stream()
    }

    public func folders() async throws -> [Folder] {
        box.value
    }

    public func create(_ folder: Folder) async throws {
        box.mutate { $0.append(folder) }
    }

    public func update(_ folder: Folder) async throws {
        box.mutate { list in
            if let index = list.firstIndex(where: { $0.id == folder.id }) {
                list[index] = folder
            }
        }
    }

    /// Deletes the folder with all subfolders; tracks are not touched.
    public func delete(id: Folder.ID) async throws {
        box.mutate { list in
            var doomed: Set<Folder.ID> = [id]
            var changed = true
            while changed {
                changed = false
                for folder in list where folder.parentID.map(doomed.contains) == true && doomed.insert(folder.id).inserted {
                    changed = true
                }
            }
            list.removeAll { doomed.contains($0.id) }
        }
    }
}

public final class InMemoryTrackRepository: TrackRepository {
    private let box: ObservableBox<[Track]>
    private let folders: InMemoryFolderRepository?

    /// `folders` is needed only to resolve `includeSubfolders`.
    public init(tracks: [Track] = [], folders: InMemoryFolderRepository? = nil) {
        box = ObservableBox(tracks)
        self.folders = folders
    }

    public var snapshot: [Track] {
        box.value
    }

    public func observeTracks(sortedBy sort: TrackSort) -> AsyncStream<[Track]> {
        let source = box.stream()
        return AsyncStream { continuation in
            let task = Task {
                for await list in source {
                    continuation.yield(Self.sorted(list, by: sort))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func tracks(ids: [Track.ID]) async throws -> [Track] {
        let all = box.value
        return ids.compactMap { id in all.first { $0.id == id } }
    }

    public func tracks(inFolder folderID: Folder.ID?, includeSubfolders: Bool) async throws -> [Track] {
        let all = box.value
        guard includeSubfolders else { return all.filter { $0.folderID == folderID } }
        guard let folderID else { return all }
        var scope: Set<Folder.ID> = [folderID]
        var changed = true
        let allFolders = folders?.snapshot ?? []
        while changed {
            changed = false
            for folder in allFolders where folder.parentID.map(scope.contains) == true && scope.insert(folder.id).inserted {
                changed = true
            }
        }
        return all.filter { $0.folderID.map(scope.contains) == true }
    }

    public func search(_ query: String, sortedBy sort: TrackSort) async throws -> [Track] {
        let needle = Self.fold(query)
        let matches = box.value.filter { track in
            [track.title, track.artist, track.album].contains { Self.fold($0).contains(needle) }
        }
        return Self.sorted(matches, by: sort)
    }

    public func track(withContentHash hash: String) async throws -> Track? {
        box.value.first { $0.contentHash == hash }
    }

    public func add(_ tracks: [Track]) async throws {
        box.mutate { $0.append(contentsOf: tracks) }
    }

    public func update(_ track: Track) async throws {
        box.mutate { list in
            if let index = list.firstIndex(where: { $0.id == track.id }) {
                list[index] = track
            }
        }
    }

    public func move(trackIDs: [Track.ID], toFolder folderID: Folder.ID?) async throws {
        box.mutate { list in
            for index in list.indices where trackIDs.contains(list[index].id) {
                list[index].folderID = folderID
            }
        }
    }

    public func delete(ids: [Track.ID]) async throws {
        box.mutate { $0.removeAll { ids.contains($0.id) } }
    }

    public func markPlayed(id: Track.ID, at date: Date) async throws {
        box.mutate { list in
            if let index = list.firstIndex(where: { $0.id == id }) {
                list[index].playCount += 1
                list[index].lastPlayedAt = date
            }
        }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func sorted(_ tracks: [Track], by sort: TrackSort) -> [Track] {
        let ordered = tracks.sorted { lhs, rhs in
            switch sort.field {
            case .title: lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .artist: lhs.artist.localizedStandardCompare(rhs.artist) == .orderedAscending
            case .dateAdded: lhs.dateAdded < rhs.dateAdded
            case .duration: lhs.duration < rhs.duration
            case .playCount: lhs.playCount < rhs.playCount
            }
        }
        return sort.ascending ? ordered : ordered.reversed()
    }
}

public final class InMemoryPlaylistRepository: PlaylistRepository {
    private struct State {
        var playlists: [Playlist] = []
        var entries: [Playlist.ID: [PlaylistEntry]] = [:]
    }

    private let box = ObservableBox(State())

    public init() {}

    public var playlists: [Playlist] {
        box.value.playlists
    }

    public func entries(of id: Playlist.ID) -> [PlaylistEntry] {
        box.value.entries[id] ?? []
    }

    public func observePlaylists() -> AsyncStream<[Playlist]> {
        let source = box.stream()
        return AsyncStream { continuation in
            let task = Task {
                for await state in source {
                    continuation.yield(state.playlists)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func observeEntries(of playlistID: Playlist.ID) -> AsyncStream<[PlaylistEntry]> {
        let source = box.stream()
        return AsyncStream { continuation in
            let task = Task {
                for await state in source {
                    continuation.yield(state.entries[playlistID] ?? [])
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func create(_ playlist: Playlist) async throws {
        box.mutate {
            $0.playlists.append(playlist)
            $0.entries[playlist.id] = []
        }
    }

    public func update(_ playlist: Playlist) async throws {
        box.mutate { state in
            if let index = state.playlists.firstIndex(where: { $0.id == playlist.id }) {
                state.playlists[index] = playlist
            }
        }
    }

    public func delete(id: Playlist.ID) async throws {
        box.mutate {
            $0.playlists.removeAll { $0.id == id }
            $0.entries[id] = nil
        }
    }

    public func append(trackIDs: [Track.ID], to playlistID: Playlist.ID) async throws {
        box.mutate { state in
            var list = state.entries[playlistID] ?? []
            for trackID in trackIDs {
                list.append(PlaylistEntry(trackID: trackID, sortIndex: list.count))
            }
            state.entries[playlistID] = list
        }
    }

    public func moveEntries(fromOffsets source: IndexSet, toOffset destination: Int, in playlistID: Playlist.ID) async throws {
        box.mutate { state in
            var list = state.entries[playlistID] ?? []
            let moving = source.filter { list.indices.contains($0) }
            let moved = moving.map { list[$0] }
            for offset in moving.reversed() {
                list.remove(at: offset)
            }
            list.insert(contentsOf: moved, at: destination - moving.filter { $0 < destination }.count)
            for index in list.indices {
                list[index].sortIndex = index
            }
            state.entries[playlistID] = list
        }
    }

    public func removeEntries(ids: [PlaylistEntry.ID]) async throws {
        box.mutate { state in
            for key in state.entries.keys {
                var list = state.entries[key] ?? []
                list.removeAll { ids.contains($0.id) }
                for index in list.indices {
                    list[index].sortIndex = index
                }
                state.entries[key] = list
            }
        }
    }
}

public final class InMemoryEQPresetRepository: EQPresetRepository {
    private let box: ObservableBox<[EQPreset]>

    public init(presets: [EQPreset] = []) {
        box = ObservableBox(presets)
    }

    public var snapshot: [EQPreset] {
        box.value
    }

    public func observePresets() -> AsyncStream<[EQPreset]> {
        box.stream()
    }

    public func save(_ preset: EQPreset) async throws {
        box.mutate { list in
            if let index = list.firstIndex(where: { $0.id == preset.id }) {
                list[index] = preset
            } else {
                list.append(preset)
            }
        }
    }

    public func delete(id: EQPreset.ID) async throws {
        box.mutate { $0.removeAll { $0.id == id } }
    }
}

public final class InMemorySettingsRepository: SettingsRepository {
    private let box: ObservableBox<AppSettings>

    public init(settings: AppSettings = AppSettings()) {
        box = ObservableBox(settings)
    }

    public func load() -> AppSettings {
        box.value
    }

    public func save(_ settings: AppSettings) {
        box.mutate { $0 = settings }
    }

    public func observe() -> AsyncStream<AppSettings> {
        box.stream()
    }
}

public final class InMemoryPlaybackStateRepository: PlaybackStateRepository {
    private let box: ObservableBox<PlaybackState?>

    public init(state: PlaybackState? = nil) {
        box = ObservableBox(state)
    }

    public func load() async -> PlaybackState? {
        box.value
    }

    public func save(_ state: PlaybackState) async throws {
        box.mutate { $0 = state }
    }
}
