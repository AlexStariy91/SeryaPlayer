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
    /// Theme and accent, observed by the root view. Kept apart from the rest of `AppSettings` so that
    /// equalizer or sort changes don't re-render the whole tree (and rebuild open sheets mid-update).
    private(set) var theme: AppTheme
    private(set) var accentColorID: String

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
    /// Shared by every import path so the Library shows progress for all of them.
    /// Optional to match `LibraryDependencies.importProgress`; a non-optional property would not satisfy
    /// the requirement and the protocol extension's `nil` would be used instead.
    let importProgress: ImportProgressCenter?
    @ObservationIgnored private let seedDirectory: URL?

    init(environment: AppEnvironment) throws {
        flags = .default
        seedDirectory = environment.seedDirectory
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
            nowPlaying: NowPlayingCenter(placeholderArtwork: NowPlayingPlaceholder.image),
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

        let progressCenter = ImportProgressCenter()
        importProgress = progressCenter
        let importTracks = ImportTracksUseCase(
            files: fileStore,
            metadata: metadataReader,
            artwork: artworkStore,
            tracks: trackRepository,
            folders: folderRepository,
            progressCenter: progressCenter
        )
        inboxProcessor = InboxProcessor(fileStore: fileStore) { urls in
            await importTracks(urls: urls)
        }

        let settings = settingsRepository.load()
        theme = settings.theme
        accentColorID = settings.accentColorID
        player.apply(settings.equalizer)
    }

    // MARK: - Use cases

    var importTracks: ImportTracksUseCase {
        ImportTracksUseCase(
            files: fileStore,
            metadata: metadataReader,
            artwork: artworkStore,
            tracks: trackRepository,
            folders: folderRepository,
            progressCenter: importProgress
        )
    }

    // MARK: - App lifecycle

    /// Restores the queue (paused) and picks up files dropped into the inboxes while the app was closed.
    func didLaunch() async {
        if let seedDirectory {
            let urls = (try? FileManager.default.contentsOfDirectory(at: seedDirectory, includingPropertiesForKeys: nil)) ?? []
            _ = await importTracks(urls: urls.sorted { $0.lastPathComponent < $1.lastPathComponent })
        }
        await player.restore()
        _ = await inboxProcessor.process()
    }

    /// Runs for the app's lifetime.
    func observeSettings() async {
        for await updated in settingsRepository.observe() {
            if updated.theme != theme {
                theme = updated.theme
            }
            if updated.accentColorID != accentColorID {
                accentColorID = updated.accentColorID
            }
        }
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
