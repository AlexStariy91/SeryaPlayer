import Domain
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var theme: AppTheme
    private(set) var accentColorID: String
    /// `nil` while the size is being computed.
    private(set) var librarySize: Int64?
    private(set) var artworkCacheSize: Int64?
    private(set) var isClearingArtwork = false
    var errorMessage: String?

    let appInfo: AppInfo

    private let settingsRepository: any SettingsRepository
    private let fileStore: any FileStoring
    private let artworkStore: any ArtworkStoring

    init(dependencies: some SettingsDependencies, appInfo: AppInfo = .main) {
        settingsRepository = dependencies.settingsRepository
        fileStore = dependencies.fileStore
        artworkStore = dependencies.artworkStore
        self.appInfo = appInfo
        let settings = dependencies.settingsRepository.load()
        theme = settings.theme
        accentColorID = settings.accentColorID
    }

    /// Follows the repository until cancelled, so the screen reflects changes made elsewhere.
    func observeSettings() async {
        for await settings in settingsRepository.observe() {
            theme = settings.theme
            accentColorID = settings.accentColorID
        }
    }

    /// Both sizes are computed by the stores off the main actor.
    func refreshSizes() async {
        async let library = fileStore.librarySize()
        async let artwork = artworkStore.cacheSize()
        librarySize = await library
        artworkCacheSize = await artwork
    }

    func select(theme: AppTheme) {
        self.theme = theme
        update { $0.theme = theme }
    }

    func select(accentColorID: String) {
        self.accentColorID = accentColorID
        update { $0.accentColorID = accentColorID }
    }

    /// Drops the downscaled copies only. Originals stay on disk, so every `Track.artworkKey` stays valid
    /// and covers are rebuilt on demand.
    func clearArtworkCache() async {
        isClearingArtwork = true
        defer { isClearingArtwork = false }
        do {
            try await artworkStore.clearCache()
        } catch {
            errorMessage = Strings.clearFailed
        }
        artworkCacheSize = await artworkStore.cacheSize()
    }

    /// Saves on top of the freshly loaded settings, so fields owned by other screens (sort, equalizer) are kept.
    private func update(_ change: (inout AppSettings) -> Void) {
        var settings = settingsRepository.load()
        change(&settings)
        settingsRepository.save(settings)
    }
}
