import CoreData
import Domain
import Foundation

public final class CoreDataFolderRepository: FolderRepository {
    private let persistence: PersistenceController

    public init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    public func observeFolders() -> AsyncStream<[Folder]> {
        FetchedResultsObserver.stream(in: persistence) {
            Self.request()
        } transform: { objects in
            objects.map { $0.toDomain() }
        }
    }

    public func folders() async throws -> [Folder] {
        try await persistence.performRead { context in
            try context.fetch(Self.request()).map { $0.toDomain() }
        }
    }

    public func create(_ folder: Folder) async throws {
        try await persistence.performWrite { context in
            let object = CDFolder(context: context)
            object.apply(folder)
            object.parent = try Self.parent(of: folder, in: context)
        }
    }

    public func update(_ folder: Folder) async throws {
        try await persistence.performWrite { context in
            let object = try context.fetchOrThrow(CDFolder.fetchRequest(), id: folder.id, entity: CDFolder.entityName)
            object.apply(folder)
            if object.parent?.id != folder.parentID {
                object.parent = try Self.parent(of: folder, in: context)
            }
        }
    }

    /// Subfolders go with it (cascade); tracks only lose their folder link (nullify).
    public func delete(id: Folder.ID) async throws {
        try await persistence.performWrite { context in
            if let object = try context.fetchOne(CDFolder.fetchRequest(), id: id) {
                context.delete(object)
            }
        }
    }

    private static func request() -> NSFetchRequest<CDFolder> {
        let request = CDFolder.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "sortIndex", ascending: true),
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:))),
            NSSortDescriptor(key: "createdAt", ascending: true),
        ]
        request.relationshipKeyPathsForPrefetching = ["parent"]
        return request
    }

    private static func parent(of folder: Folder, in context: NSManagedObjectContext) throws -> CDFolder? {
        try folder.parentID.map { try context.fetchOrThrow(CDFolder.fetchRequest(), id: $0, entity: CDFolder.entityName) }
    }
}
