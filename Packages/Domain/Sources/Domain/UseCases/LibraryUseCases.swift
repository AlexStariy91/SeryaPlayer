import Foundation

public struct ObserveTracksUseCase: Sendable {
    private let tracks: any TrackRepository

    public init(tracks: any TrackRepository) {
        self.tracks = tracks
    }

    public func callAsFunction(sortedBy sort: TrackSort = TrackSort()) -> AsyncStream<[Track]> {
        tracks.observeTracks(sortedBy: sort)
    }
}

public struct SearchTracksUseCase: Sendable {
    private let tracks: any TrackRepository

    public init(tracks: any TrackRepository) {
        self.tracks = tracks
    }

    /// A blank query finds nothing; the caller shows the regular list instead.
    public func callAsFunction(_ query: String, sortedBy sort: TrackSort = TrackSort()) async throws -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await tracks.search(trimmed, sortedBy: sort)
    }
}

// MARK: - Folders

public struct ObserveFoldersUseCase: Sendable {
    private let folders: any FolderRepository

    public init(folders: any FolderRepository) {
        self.folders = folders
    }

    public func callAsFunction() -> AsyncStream<[Folder]> {
        folders.observeFolders()
    }
}

public struct CreateFolderUseCase: Sendable {
    private let folders: any FolderRepository

    public init(folders: any FolderRepository) {
        self.folders = folders
    }

    @discardableResult
    public func callAsFunction(name: String, parentID: Folder.ID? = nil) async throws -> Folder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.emptyName }
        let siblings = try await folders.folders().filter { $0.parentID == parentID }
        let folder = Folder(name: trimmed, parentID: parentID, sortIndex: (siblings.map(\.sortIndex).max() ?? -1) + 1)
        try await folders.create(folder)
        return folder
    }
}

public struct RenameFolderUseCase: Sendable {
    private let folders: any FolderRepository

    public init(folders: any FolderRepository) {
        self.folders = folders
    }

    public func callAsFunction(id: Folder.ID, to name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.emptyName }
        guard var folder = try await folders.folders().first(where: { $0.id == id }) else { throw DomainError.folderNotFound }
        folder.name = trimmed
        try await folders.update(folder)
    }
}

public struct MoveFolderUseCase: Sendable {
    private let folders: any FolderRepository

    public init(folders: any FolderRepository) {
        self.folders = folders
    }

    /// Moves a folder under `newParentID` (nil = root). Moving into itself or a descendant is rejected.
    public func callAsFunction(id: Folder.ID, toParent newParentID: Folder.ID?) async throws {
        let all = try await folders.folders()
        guard var folder = all.first(where: { $0.id == id }) else { throw DomainError.folderNotFound }
        if let newParentID {
            guard all.contains(where: { $0.id == newParentID }) else { throw DomainError.folderNotFound }
            if FolderTree.descendantIDs(of: id, in: all).union([id]).contains(newParentID) {
                throw DomainError.folderCycle
            }
        }
        folder.parentID = newParentID
        folder.sortIndex = (all.filter { $0.parentID == newParentID }.map(\.sortIndex).max() ?? -1) + 1
        try await folders.update(folder)
    }
}

/// Deletes a folder with all its subfolders. What happens to the tracks inside is decided by `policy`.
public struct DeleteFolderUseCase: Sendable {
    private let folders: any FolderRepository
    private let tracks: any TrackRepository
    private let files: any FileStoring

    public init(folders: any FolderRepository, tracks: any TrackRepository, files: any FileStoring) {
        self.folders = folders
        self.tracks = tracks
        self.files = files
    }

    public func callAsFunction(id: Folder.ID, policy: FolderDeletionPolicy) async throws {
        guard try await folders.folders().contains(where: { $0.id == id }) else { throw DomainError.folderNotFound }
        let affected = try await tracks.tracks(inFolder: id, includeSubfolders: true)
        switch policy {
        case .moveTracksToRoot:
            try await tracks.move(trackIDs: affected.map(\.id), toFolder: nil)
        case .deleteTracks:
            try await tracks.delete(ids: affected.map(\.id))
            for track in affected {
                try? await files.deleteFile(relativePath: track.relativePath)
            }
        }
        try await folders.delete(id: id)
    }
}

enum FolderTree {
    static func descendantIDs(of id: Folder.ID, in folders: [Folder]) -> Set<Folder.ID> {
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
