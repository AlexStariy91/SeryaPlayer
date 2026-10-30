import Domain
import DomainTestSupport
@testable import EqualizerFeature

/// Counts `save` calls. `@unchecked Sendable`: the counter is only touched from the main actor in tests.
final class CountingSettingsRepository: SettingsRepository, @unchecked Sendable {
    private let base: InMemorySettingsRepository
    private(set) var saveCount = 0

    init(_ base: InMemorySettingsRepository) {
        self.base = base
    }

    func load() -> AppSettings {
        base.load()
    }

    func observe() -> AsyncStream<AppSettings> {
        base.observe()
    }

    func save(_ settings: AppSettings) {
        saveCount += 1
        base.save(settings)
    }
}

@MainActor
struct TestDependencies: EqualizerDependencies {
    let presets: InMemoryEQPresetRepository
    let settings: CountingSettingsRepository
    let playback: FakePlaybackController

    var presetRepository: any EQPresetRepository {
        presets
    }

    var settingsRepository: any SettingsRepository {
        settings
    }

    var player: any PlaybackControlling {
        playback
    }

    init(userPresets: [EQPreset] = [], equalizer: EQSettings = EQSettings()) {
        presets = InMemoryEQPresetRepository(presets: userPresets)
        var appSettings = AppSettings()
        appSettings.equalizer = equalizer
        settings = CountingSettingsRepository(InMemorySettingsRepository(settings: appSettings))
        playback = FakePlaybackController()
    }

    func makeViewModel() -> EqualizerViewModel {
        EqualizerViewModel(dependencies: self)
    }

    var equalizer: EQSettings {
        settings.load().equalizer
    }
}

extension EqualizerViewModel {
    /// Loads the current user presets, then stops following.
    func loadPresets(from deps: TestDependencies) async {
        let task = Task { await start() }
        // The first element of each stream is the current state; give the main actor a few turns to deliver it.
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        task.cancel()
        _ = deps
    }
}
