import Domain
import Foundation
import Observation

/// Playlist CRUD for the Playlists screen. The list itself comes from `LibraryStore`.
@MainActor
@Observable
final class PlaylistsViewModel {
    private(set) var errorMessage: String?
    var isShowingError = false

    @ObservationIgnored private let createPlaylist: CreatePlaylistUseCase
    @ObservationIgnored private let renamePlaylist: RenamePlaylistUseCase
    @ObservationIgnored private let deletePlaylist: DeletePlaylistUseCase

    init(playlists: any PlaylistRepository) {
        createPlaylist = CreatePlaylistUseCase(playlists: playlists)
        renamePlaylist = RenamePlaylistUseCase(playlists: playlists)
        deletePlaylist = DeletePlaylistUseCase(playlists: playlists)
    }

    @discardableResult
    func create(named name: String) async -> Playlist? {
        await perform { try await self.createPlaylist(name: name) }
    }

    func rename(_ playlist: Playlist, to name: String) async {
        await perform { try await self.renamePlaylist(playlist, to: name) }
    }

    func delete(_ playlist: Playlist) async {
        await perform { try await self.deletePlaylist(id: playlist.id) }
    }

    private func perform<T: Sendable>(_ work: () async throws -> T) async -> T? {
        do {
            return try await work()
        } catch DomainError.emptyName {
            show(String(localized: "The name can't be empty.", bundle: .module))
        } catch {
            show(error.localizedDescription)
        }
        return nil
    }

    private func show(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}
