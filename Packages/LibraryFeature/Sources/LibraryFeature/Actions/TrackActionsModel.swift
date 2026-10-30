import Domain
import Foundation
import Observation

/// Track actions shared by every list (swipe actions and context menus) and the sheets they open.
/// Presented once, at the root, by `TrackActionsPresenter`.
@MainActor
@Observable
final class TrackActionsModel {
    enum Sheet: Identifiable {
        case addToPlaylist([Track])
        case moveToFolder([Track])
        case editTags(Track)

        var id: String {
            switch self {
            case let .addToPlaylist(tracks): "playlist-" + tracks.map(\.id.uuidString).joined()
            case let .moveToFolder(tracks): "folder-" + tracks.map(\.id.uuidString).joined()
            case let .editTags(track): "tags-" + track.id.uuidString
            }
        }
    }

    var sheet: Sheet?
    /// Tracks waiting for the delete confirmation.
    var pendingDeletion: [Track] = []
    var isConfirmingDeletion = false
    var isShowingError = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let player: any PlaybackControlling
    @ObservationIgnored private let addToPlaylist: AddTracksToPlaylistUseCase
    @ObservationIgnored private let createPlaylist: CreatePlaylistUseCase
    @ObservationIgnored private let moveTracks: MoveTracksUseCase
    @ObservationIgnored private let deleteTracks: DeleteTracksUseCase
    @ObservationIgnored let editTags: EditTrackTagsUseCase

    init(
        player: any PlaybackControlling,
        tracks: any TrackRepository,
        playlists: any PlaylistRepository,
        files: any FileStoring,
        artwork: any ArtworkStoring
    ) {
        self.player = player
        addToPlaylist = AddTracksToPlaylistUseCase(playlists: playlists)
        createPlaylist = CreatePlaylistUseCase(playlists: playlists)
        moveTracks = MoveTracksUseCase(tracks: tracks)
        deleteTracks = DeleteTracksUseCase(tracks: tracks, files: files)
        editTags = EditTrackTagsUseCase(tracks: tracks, artwork: artwork)
    }

    func playNext(_ tracks: [Track]) {
        player.playNext(tracks)
    }

    func playLast(_ tracks: [Track]) {
        player.addToQueue(tracks)
    }

    func requestAddToPlaylist(_ tracks: [Track]) {
        sheet = .addToPlaylist(tracks)
    }

    func requestMoveToFolder(_ tracks: [Track]) {
        sheet = .moveToFolder(tracks)
    }

    func requestEditTags(_ track: Track) {
        sheet = .editTags(track)
    }

    func requestDelete(_ tracks: [Track]) {
        pendingDeletion = tracks
        isConfirmingDeletion = true
    }

    func add(_ tracks: [Track], to playlist: Playlist) async {
        await perform { try await self.addToPlaylist(trackIDs: tracks.map(\.id), to: playlist.id) }
    }

    func addToNewPlaylist(named name: String, tracks: [Track]) async {
        await perform { _ = try await self.createPlaylist(name: name, trackIDs: tracks.map(\.id)) }
    }

    func move(_ tracks: [Track], toFolder folderID: Folder.ID?) async {
        await perform { try await self.moveTracks(tracks.map(\.id), toFolder: folderID) }
    }

    func confirmDeletion() async {
        let doomed = pendingDeletion
        pendingDeletion = []
        await perform { try await self.deleteTracks(doomed) }
    }

    private func perform(_ work: () async throws -> Void) async {
        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }
}
