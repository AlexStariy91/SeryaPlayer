import CoreData
import Domain
import Foundation

public final class CoreDataPlaylistRepository: PlaylistRepository {
    private let persistence: PersistenceController

    public init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    public func observePlaylists() -> AsyncStream<[Playlist]> {
        FetchedResultsObserver.stream(in: persistence) {
            let request = CDPlaylist.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:))),
                NSSortDescriptor(key: "createdAt", ascending: true),
            ]
            return request
        } transform: { (objects: [CDPlaylist]) in
            objects.map { $0.toDomain() }
        }
    }

    public func observeEntries(of playlistID: Playlist.ID) -> AsyncStream<[PlaylistEntry]> {
        FetchedResultsObserver.stream(in: persistence) {
            let request = Self.entriesRequest(playlistID: playlistID)
            request.relationshipKeyPathsForPrefetching = ["track"]
            return request
        } transform: { (objects: [CDPlaylistEntry]) in
            objects.compactMap { $0.toDomain() }
        }
    }

    public func create(_ playlist: Playlist) async throws {
        try await persistence.performWrite { context in
            CDPlaylist(context: context).apply(playlist)
        }
    }

    public func update(_ playlist: Playlist) async throws {
        try await persistence.performWrite { context in
            try context.fetchOrThrow(CDPlaylist.fetchRequest(), id: playlist.id, entity: CDPlaylist.entityName).apply(playlist)
        }
    }

    public func delete(id: Playlist.ID) async throws {
        try await persistence.performWrite { context in
            if let object = try context.fetchOne(CDPlaylist.fetchRequest(), id: id) {
                context.delete(object)
            }
        }
    }

    /// Appends in the given order; the same track may be added more than once. Unknown IDs are skipped.
    public func append(trackIDs: [Track.ID], to playlistID: Playlist.ID) async throws {
        guard !trackIDs.isEmpty else { return }
        try await persistence.performWrite { context in
            let playlist = try context.fetchOrThrow(CDPlaylist.fetchRequest(), id: playlistID, entity: CDPlaylist.entityName)
            let request = CDTrack.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", trackIDs)
            let tracks = try Dictionary(context.fetch(request).map { ($0.id, $0) }) { first, _ in first }
            var nextIndex = (playlist.entries.map(\.sortIndex).max() ?? -1) + 1
            for trackID in trackIDs {
                guard let track = tracks[trackID] else { continue }
                let entry = CDPlaylistEntry(context: context)
                entry.id = UUID()
                entry.sortIndex = nextIndex
                entry.track = track
                entry.playlist = playlist
                nextIndex += 1
            }
        }
    }

    /// Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`; `sortIndex` is renumbered from 0.
    public func moveEntries(fromOffsets source: IndexSet, toOffset destination: Int, in playlistID: Playlist.ID) async throws {
        try await persistence.performWrite { context in
            var entries = try context.fetch(Self.entriesRequest(playlistID: playlistID))
            entries.moveElements(fromOffsets: source, toOffset: destination)
            Self.renumber(entries)
        }
    }

    public func removeEntries(ids: [PlaylistEntry.ID]) async throws {
        guard !ids.isEmpty else { return }
        try await persistence.performWrite { context in
            let request = CDPlaylistEntry.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids)
            let removed = try context.fetch(request)
            let playlists = Set(removed.compactMap(\.playlist))
            removed.forEach(context.delete)
            for playlist in playlists {
                let remaining = playlist.entries.filter { !$0.isDeleted }.sorted { $0.sortIndex < $1.sortIndex }
                Self.renumber(remaining)
            }
        }
    }

    private static func entriesRequest(playlistID: Playlist.ID) -> NSFetchRequest<CDPlaylistEntry> {
        let request = CDPlaylistEntry.fetchRequest()
        request.predicate = NSPredicate(format: "playlist.id == %@", playlistID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "sortIndex", ascending: true)]
        return request
    }

    private static func renumber(_ entries: [CDPlaylistEntry]) {
        for (index, entry) in entries.enumerated() where entry.sortIndex != Int64(index) {
            entry.sortIndex = Int64(index)
        }
    }
}

extension Array {
    /// Foundation counterpart of SwiftUI's `move(fromOffsets:toOffset:)`.
    mutating func moveElements(fromOffsets source: IndexSet, toOffset destination: Int) {
        let valid = source.filter { indices.contains($0) }
        let moving = valid.map { self[$0] }
        let insertionIndex = destination - valid.count { $0 < destination }
        for index in valid.reversed() {
            remove(at: index)
        }
        insert(contentsOf: moving, at: Swift.min(Swift.max(insertionIndex, 0), count))
    }
}
