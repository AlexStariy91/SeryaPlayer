import CoreData
import Foundation
import Shared

/// The Core Data stack. One instance per app (created in `AppContainer`).
///
/// - `viewContext` is main-queue and merges changes saved by other contexts automatically.
/// - Writes go through background contexts (`performWrite`).
/// - Observation uses private-queue contexts registered here, so batch inserts (which bypass
///   contexts) can be merged into them as well.
///
/// `@unchecked Sendable`: `NSPersistentContainer` is not annotated, but the members used here
/// (`newBackgroundContext`, `viewContext`, the coordinator) are thread-safe; contexts are only
/// touched inside their own `perform`. The observation registry is guarded by a lock.
public final class PersistenceController: @unchecked Sendable {
    public enum StoreKind: Sendable {
        /// SQLite file at the given URL (the app uses `StoragePaths.database`).
        case file(URL)
        /// Not persisted; for tests and previews.
        case inMemory
    }

    /// Loaded once per process: several `NSManagedObjectModel` instances for the same classes make
    /// Core Data warn about ambiguous entity descriptions.
    /// `nonisolated(unsafe)`: the model is immutable once loaded and Core Data reads it from any queue.
    nonisolated(unsafe) static let model: NSManagedObjectModel = {
        guard let url = compiledModelURL(), let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("SeryaPlayer.momd is missing from the DataLayer bundle")
        }
        return model
    }()

    private static func compiledModelURL() -> URL? {
        if let url = Bundle.module.url(forResource: "SeryaPlayer", withExtension: "momd") {
            return url
        }
        #if os(macOS)
            // Xcode compiles `.xcdatamodeld` into `.momd`, but command-line `swift build` only copies it.
            // For `swift test` on macOS, compile the copied model with `momc` once per process.
            guard let source = Bundle.module.url(forResource: "SeryaPlayer", withExtension: "xcdatamodeld") else { return nil }
            let output = FileManager.default.temporaryDirectory.appending(path: "DataLayerModel-\(UUID().uuidString)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["momc", source.path, output.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do {
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }
            let compiled = output.appending(path: "SeryaPlayer.momd")
            return FileManager.default.fileExists(atPath: compiled.path) ? compiled : nil
        #else
            return nil
        #endif
    }

    let container: NSPersistentContainer
    private let observationContexts = NSHashTable<NSManagedObjectContext>.weakObjects()
    private let observationLock = NSLock()

    public convenience init() throws {
        try self.init(store: .file(StoragePaths.database))
    }

    public init(store: StoreKind) throws {
        container = NSPersistentContainer(name: "SeryaPlayer", managedObjectModel: Self.model)
        let description: NSPersistentStoreDescription
        switch store {
        case let .file(url):
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            description = NSPersistentStoreDescription(url: url)
        case .inMemory:
            // SQLite at /dev/null: lives in memory, yet supports batch requests unlike
            // NSInMemoryStoreType. Each container gets its own private store.
            description = NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))
        }
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        var loadError: Swift.Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError {
            throw loadError
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.name = "viewContext"
    }

    /// Main-queue context for UI reads.
    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }

    /// A private-queue context that follows store changes, including batch inserts.
    func newObservationContext() -> NSManagedObjectContext {
        let context = newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        observationLock.withLock { observationContexts.add(context) }
        return context
    }

    /// Runs `block` on a fresh background context and saves it if it has changes.
    func performWrite<T: Sendable>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = newBackgroundContext()
        return try await context.perform {
            let result = try block(context)
            if context.hasChanges {
                try context.save()
            }
            return result
        }
    }

    /// Runs `block` on a fresh background context without saving.
    func performRead<T: Sendable>(_ block: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = newBackgroundContext()
        return try await context.perform {
            try block(context)
        }
    }

    /// Batch requests write straight to the store; this pushes their result into the view context
    /// and every live observation context.
    func mergeBatchChanges(_ changes: [AnyHashable: Any]) {
        let contexts = observationLock.withLock { observationContexts.allObjects } + [container.viewContext]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: contexts)
    }
}
