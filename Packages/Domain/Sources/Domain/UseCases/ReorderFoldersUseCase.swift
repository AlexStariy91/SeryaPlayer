import Foundation

/// Persists a manual order of sibling folders: `orderedIDs[i]` gets `sortIndex == i`.
/// Folders whose index is already right are not written. Unknown IDs are ignored.
public struct ReorderFoldersUseCase: Sendable {
    private let folders: any FolderRepository

    public init(folders: any FolderRepository) {
        self.folders = folders
    }

    public func callAsFunction(orderedIDs: [Folder.ID]) async throws {
        let all = try await folders.folders()
        for (index, id) in orderedIDs.enumerated() {
            guard var folder = all.first(where: { $0.id == id }), folder.sortIndex != index else { continue }
            folder.sortIndex = index
            try await folders.update(folder)
        }
    }
}
