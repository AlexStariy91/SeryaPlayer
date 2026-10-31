import Domain
import DomainTestSupport
@testable import SettingsFeature

@MainActor
struct TestDependencies: SettingsDependencies {
    let settings: InMemorySettingsRepository
    let files = FakeFileStore()
    let artwork = FakeArtworkStore()

    var settingsRepository: any SettingsRepository {
        settings
    }

    var fileStore: any FileStoring {
        files
    }

    var artworkStore: any ArtworkStoring {
        artwork
    }

    init(settings: AppSettings = AppSettings()) {
        self.settings = InMemorySettingsRepository(settings: settings)
    }

    func makeViewModel(appInfo: AppInfo = AppInfo(name: "SeryaPlayer", version: "1.0", build: "1")) -> SettingsViewModel {
        SettingsViewModel(dependencies: self, appInfo: appInfo)
    }
}
