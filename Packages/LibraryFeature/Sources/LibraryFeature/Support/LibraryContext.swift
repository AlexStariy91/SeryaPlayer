import Domain
import Foundation

/// The feature's object graph, built once per root view and handed to screens through `init`.
@MainActor
final class LibraryContext {
    let tracks: any TrackRepository
    let playlists: any PlaylistRepository
    let folders: any FolderRepository
    let settings: any SettingsRepository
    let player: any PlaybackControlling

    let store: LibraryStore
    let actions: TrackActionsModel
    let importer: ImportViewModel
    let artwork: ArtworkResolver
    let startPlayback: StartPlaybackUseCase

    init(dependencies: some LibraryDependencies) {
        tracks = dependencies.trackRepository
        playlists = dependencies.playlistRepository
        folders = dependencies.folderRepository
        settings = dependencies.settingsRepository
        player = dependencies.player
        store = LibraryStore(tracks: dependencies.trackRepository, playlists: dependencies.playlistRepository, player: dependencies.player)
        actions = TrackActionsModel(
            player: dependencies.player,
            tracks: dependencies.trackRepository,
            playlists: dependencies.playlistRepository,
            files: dependencies.fileStore,
            artwork: dependencies.artworkStore
        )
        importer = ImportViewModel(importTracks: dependencies.importTracks)
        artwork = ArtworkResolver(store: dependencies.artworkStore)
        startPlayback = StartPlaybackUseCase(playback: dependencies.player)
    }
}
