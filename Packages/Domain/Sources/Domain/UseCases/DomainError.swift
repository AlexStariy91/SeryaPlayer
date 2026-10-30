import Foundation

public enum DomainError: Error, Sendable, Equatable {
    case emptyName
    case folderNotFound
    case playlistNotFound
    /// A folder cannot be moved into itself or into one of its descendants.
    case folderCycle
}
