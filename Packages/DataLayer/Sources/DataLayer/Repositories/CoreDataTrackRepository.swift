import CoreData
import Domain
import Foundation

public final class CoreDataTrackRepository: TrackRepository {
    /// From this many tracks on, `add` uses `NSBatchInsertRequest` instead of managed objects.
    static let batchInsertThreshold = 50

    private let persistence: PersistenceController

    public init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    public func observeTracks(sortedBy sort: TrackSort) -> AsyncStream<[Track]> {
        FetchedResultsObserver.stream(in: persistence) {
            Self.request(sortedBy: sort)
        } transform: { objects in
            objects.map { $0.toDomain() }
        }
    }

    public func tracks(ids: [Track.ID]) async throws -> [Track] {
        guard !ids.isEmpty else { return [] }
        return try await persistence.performRead { context in
            let request = Self.request()
            request.predicate = NSPredicate(format: "id IN %@", ids)
            let byID = try Dictionary(context.fetch(request).map { ($0.id, $0.toDomain()) }) { first, _ in first }
            return ids.compactMap { byID[$0] }
        }
    }

    public func tracks(inFolder folderID: Folder.ID?, includeSubfolders: Bool) async throws -> [Track] {
        try await persistence.performRead { context in
            let request = Self.request()
            switch (folderID, includeSubfolders) {
            case (nil, true):
                break
            case (nil, false):
                request.predicate = NSPredicate(format: "folder == nil")
            case let (folderID?, false):
                request.predicate = NSPredicate(format: "folder.id == %@", folderID as CVarArg)
            case let (folderID?, true):
                let ids = try Self.folderIDs(descendingFrom: folderID, in: context)
                request.predicate = NSPredicate(format: "folder.id IN %@", ids)
            }
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    public func search(_ query: String, sortedBy sort: TrackSort) async throws -> [Track] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return try await persistence.performRead { context in
            let request = Self.request(sortedBy: sort)
            if !query.isEmpty {
                request.predicate = NSPredicate(
                    format: "title CONTAINS[cd] %@ OR artist CONTAINS[cd] %@ OR album CONTAINS[cd] %@",
                    query, query, query
                )
            }
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    public func track(withContentHash hash: String) async throws -> Track? {
        try await persistence.performRead { context in
            let request = Self.request()
            request.predicate = NSPredicate(format: "contentHash == %@", hash)
            request.fetchLimit = 1
            return try context.fetch(request).first?.toDomain()
        }
    }

    public func add(_ tracks: [Track]) async throws {
        guard !tracks.isEmpty else { return }
        if tracks.count >= Self.batchInsertThreshold {
            try await batchInsert(tracks)
        } else {
            try await persistence.performWrite { context in
                let folders = try Self.folders(ids: Set(tracks.compactMap(\.folderID)), in: context)
                for track in tracks {
                    let object = CDTrack(context: context)
                    object.apply(track)
                    object.folder = track.folderID.flatMap { folders[$0] }
                }
            }
        }
    }

    private func batchInsert(_ tracks: [Track]) async throws {
        let insertedIDs = try await persistence.performWrite { context in
            let request = NSBatchInsertRequest(entityName: CDTrack.entityName, objects: tracks.map(CDTrack.batchValues(for:)))
            request.resultType = .objectIDs
            let result = try context.execute(request) as? NSBatchInsertResult
            return result?.result as? [NSManagedObjectID] ?? []
        }
        persistence.mergeBatchChanges([NSInsertedObjectsKey: insertedIDs])

        // Batch inserts cannot set relationships, so folders are linked in a regular save.
        let withFolders = tracks.filter { $0.folderID != nil }
        guard !withFolders.isEmpty else { return }
        try await persistence.performWrite { context in
            let folders = try Self.folders(ids: Set(withFolders.compactMap(\.folderID)), in: context)
            let request = Self.request()
            request.predicate = NSPredicate(format: "id IN %@", withFolders.map(\.id))
            let objects = try Dictionary(context.fetch(request).map { ($0.id, $0) }) { first, _ in first }
            for track in withFolders {
                objects[track.id]?.folder = track.folderID.flatMap { folders[$0] }
            }
        }
    }

    public func update(_ track: Track) async throws {
        try await persistence.performWrite { context in
            let object = try context.fetchOrThrow(Self.request(), id: track.id, entity: CDTrack.entityName)
            object.apply(track)
            if object.folder?.id != track.folderID {
                object.folder = try track.folderID.flatMap { try context.fetchOne(CDFolder.fetchRequest(), id: $0) }
            }
        }
    }

    public func move(trackIDs: [Track.ID], toFolder folderID: Folder.ID?) async throws {
        guard !trackIDs.isEmpty else { return }
        try await persistence.performWrite { context in
            let folder = try folderID.map { try context.fetchOrThrow(CDFolder.fetchRequest(), id: $0, entity: CDFolder.entityName) }
            let request = Self.request()
            request.predicate = NSPredicate(format: "id IN %@", trackIDs)
            for object in try context.fetch(request) {
                object.folder = folder
            }
        }
    }

    public func delete(ids: [Track.ID]) async throws {
        guard !ids.isEmpty else { return }
        try await persistence.performWrite { context in
            let request = Self.request()
            request.predicate = NSPredicate(format: "id IN %@", ids)
            for object in try context.fetch(request) {
                context.delete(object)
            }
        }
    }

    public func markPlayed(id: Track.ID, at date: Date) async throws {
        try await persistence.performWrite { context in
            let object = try context.fetchOrThrow(Self.request(), id: id, entity: CDTrack.entityName)
            object.playCount += 1
            object.lastPlayedAt = date
        }
    }

    // MARK: - Helpers

    static func request(sortedBy sort: TrackSort = TrackSort()) -> NSFetchRequest<CDTrack> {
        let request = CDTrack.fetchRequest()
        request.sortDescriptors = sort.sortDescriptors
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = ["folder"]
        return request
    }

    private static func folders(ids: Set<Folder.ID>, in context: NSManagedObjectContext) throws -> [Folder.ID: CDFolder] {
        guard !ids.isEmpty else { return [:] }
        let request = CDFolder.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", Array(ids))
        return try Dictionary(context.fetch(request).map { ($0.id, $0) }) { first, _ in first }
    }

    /// The folder itself plus every folder nested in it, at any depth.
    private static func folderIDs(descendingFrom root: Folder.ID, in context: NSManagedObjectContext) throws -> [Folder.ID] {
        let request = NSFetchRequest<NSDictionary>(entityName: CDFolder.entityName)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["id", "parent.id"]
        var children: [UUID: [UUID]] = [:]
        for row in try context.fetch(request) {
            guard let id = row["id"] as? UUID else { continue }
            if let parent = row["parent.id"] as? UUID {
                children[parent, default: []].append(id)
            }
        }
        var result = [root]
        var index = 0
        while index < result.count {
            result += children[result[index]] ?? []
            index += 1
        }
        return result
    }
}
