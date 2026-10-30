import Domain
import Foundation

/// The feature's object graph, built once per root view and handed to screens through `init`.
@MainActor
final class FoldersContext {
    let store: FoldersStore
    let player: any PlaybackControlling
    let artwork: ArtworkResolver

    let createFolder: CreateFolderUseCase
    let renameFolder: RenameFolderUseCase
    let moveFolder: MoveFolderUseCase
    let deleteFolder: DeleteFolderUseCase
    let reorderFolders: ReorderFoldersUseCase
    let moveTracks: MoveTracksUseCase
    let deleteTracks: DeleteTracksUseCase
    let startPlayback: StartPlaybackUseCase

    init(dependencies: some FoldersDependencies) {
        let folders = dependencies.folderRepository
        let tracks = dependencies.trackRepository
        let files = dependencies.fileStore
        player = dependencies.player
        store = FoldersStore(folders: folders, tracks: tracks, player: dependencies.player)
        artwork = ArtworkResolver(store: dependencies.artworkStore)
        createFolder = CreateFolderUseCase(folders: folders)
        renameFolder = RenameFolderUseCase(folders: folders)
        moveFolder = MoveFolderUseCase(folders: folders)
        deleteFolder = DeleteFolderUseCase(folders: folders, tracks: tracks, files: files)
        reorderFolders = ReorderFoldersUseCase(folders: folders)
        moveTracks = MoveTracksUseCase(tracks: tracks)
        deleteTracks = DeleteTracksUseCase(tracks: tracks, files: files)
        startPlayback = StartPlaybackUseCase(playback: dependencies.player)
    }
}
