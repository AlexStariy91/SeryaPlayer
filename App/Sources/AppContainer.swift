import DataLayer
import Domain
import Foundation
import Observation
import Playback
import Shared

/// Composition Root: the only place where DataLayer and Playback implementations are assembled.
/// Features receive only Domain protocols and use cases through their factories.
///
/// Repositories, the file store and the player are single instances created here;
/// use cases are cheap structs created on demand.
@MainActor
@Observable
final class AppContainer {
    let flags: FeatureFlags
    let router = AppRouter()

    @ObservationIgnored let trackRepository: any TrackRepository
    @ObservationIgnored let folderRepository: any FolderRepository
    @ObservationIgnored let playlistRepository: any PlaylistRepository
    @ObservationIgnored let presetRepository: any EQPresetRepository
    @ObservationIgnored let settingsRepository: any SettingsRepository
    @ObservationIgnored let fileStore: any FileStoring
    @ObservationIgnored let artworkStore: any ArtworkStoring
    @ObservationIgnored let metadataReader: any MetadataReading
    @ObservationIgnored let player: any PlaybackControlling

    @ObservationIgnored private let persistence: PersistenceController
    @ObservationIgnored private let remoteCommands: RemoteCommands
    @ObservationIgnored private let inboxProcessor: InboxProcessor

    init(environment: AppEnvironment) throws {
        flags = .default
        persistence = try PersistenceController(store: environment.store)

        trackRepository = CoreDataTrackRepository(persistence: persistence)
        folderRepository = CoreDataFolderRepository(persistence: persistence)
        playlistRepository = CoreDataPlaylistRepository(persistence: persistence)
        presetRepository = CoreDataEQPresetRepository(persistence: persistence)
        settingsRepository = UserDefaultsSettingsRepository(defaults: environment.defaults)

        let fileStore = FileStore(rootURL: environment.libraryURL, documentsInboxURL: environment.documentsInboxURL)
        let artworkStore = ArtworkCache(directoryURL: fileStore.artworkURL)
        self.fileStore = fileStore
        self.artworkStore = artworkStore
        metadataReader = MetadataReader()

        let player = DefaultPlaybackService(
            engine: AVAudioPlaybackEngine(session: AudioSessionManager()),
            trackRepository: trackRepository,
            stateRepository: FilePlaybackStateRepository(fileURL: environment.playbackStateURL),
            nowPlaying: NowPlayingCenter(),
            urlForTrack: { track in fileStore.url(forRelativePath: track.relativePath) },
            artworkURLForTrack: { track in
                guard let key = track.artworkKey else { return nil }
                return await artworkStore.url(for: key, size: .large)
            }
        )
        self.player = player
        let remoteCommands = RemoteCommands()
        remoteCommands.attach(to: player)
        self.remoteCommands = remoteCommands

        let importTracks = ImportTracksUseCase(
            files: fileStore,
            metadata: metadataReader,
            artwork: artworkStore,
            tracks: trackRepository,
            folders: folderRepository
        )
        inboxProcessor = InboxProcessor(fileStore: fileStore) { urls in
            await importTracks(urls: urls)
        }

        player.apply(settingsRepository.load().equalizer)
    }

    // MARK: - Use cases

    var importTracks: ImportTracksUseCase {
        ImportTracksUseCase(
            files: fileStore,
            metadata: metadataReader,
            artwork: artworkStore,
            tracks: trackRepository,
            folders: folderRepository
        )
    }

    // MARK: - App lifecycle

    /// Restores the queue (paused) and picks up files dropped into the inboxes while the app was closed.
    func didLaunch() async {
        await player.restore()
        _ = await inboxProcessor.process()
    }

    func didBecomeActive() async {
        _ = await inboxProcessor.process()
    }

    func didEnterBackground() async {
        await player.persist()
    }

    /// A file opened in SeryaPlayer from another app ("Open in…", AirDrop).
    func open(_ url: URL) async {
        _ = await importTracks(urls: [url])
    }
}
