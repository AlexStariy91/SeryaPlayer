import CoreData
import Domain
import Foundation

/// User presets only; built-in presets live in Domain code.
public final class CoreDataEQPresetRepository: EQPresetRepository {
    private let persistence: PersistenceController

    public init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    public func observePresets() -> AsyncStream<[EQPreset]> {
        FetchedResultsObserver.stream(in: persistence) {
            let request = CDEQPreset.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return request
        } transform: { (objects: [CDEQPreset]) in
            objects.map { $0.toDomain() }
        }
    }

    /// Inserts a new preset or overwrites the one with the same ID.
    public func save(_ preset: EQPreset) async throws {
        try await persistence.performWrite { context in
            let object = try context.fetchOne(CDEQPreset.fetchRequest(), id: preset.id) ?? CDEQPreset(context: context)
            try object.apply(preset)
        }
    }

    public func delete(id: EQPreset.ID) async throws {
        try await persistence.performWrite { context in
            if let object = try context.fetchOne(CDEQPreset.fetchRequest(), id: id) {
                context.delete(object)
            }
        }
    }
}
