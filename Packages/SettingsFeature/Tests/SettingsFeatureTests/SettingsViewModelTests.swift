import Domain
import DomainTestSupport
import Foundation
@testable import SettingsFeature
import Testing

@MainActor
struct SettingsViewModelTests {
    @Test func startsFromStoredSettings() {
        let deps = TestDependencies(settings: AppSettings(theme: .dark, accentColorID: "teal"))
        let model = deps.makeViewModel()
        #expect(model.theme == .dark)
        #expect(model.accentColorID == "teal")
    }

    @Test func selectingThemePersistsAndKeepsOtherSettings() {
        var initial = AppSettings(accentColorID: "pink")
        initial.equalizer.preamp = -4
        let deps = TestDependencies(settings: initial)
        let model = deps.makeViewModel()

        model.select(theme: .light)

        #expect(model.theme == .light)
        var expected = initial
        expected.theme = .light
        #expect(deps.settings.load() == expected)
    }

    @Test func selectingAccentPersists() {
        let deps = TestDependencies()
        let model = deps.makeViewModel()
        model.select(accentColorID: "crimson")
        #expect(model.accentColorID == "crimson")
        #expect(deps.settings.load().accentColorID == "crimson")
    }

    @Test func followsChangesMadeElsewhere() async {
        let deps = TestDependencies()
        let model = deps.makeViewModel()
        let task = Task { await model.observeSettings() }
        await Task.yield()
        deps.settings.save(AppSettings(theme: .dark, accentColorID: "green"))
        for _ in 0 ..< 50 where model.theme != .dark {
            await Task.yield()
        }
        task.cancel()
        #expect(model.theme == .dark)
        #expect(model.accentColorID == "green")
    }

    @Test func sizesAreNilUntilRefreshed() async throws {
        let deps = TestDependencies()
        _ = try await deps.files.importFile(from: URL(fileURLWithPath: "/a.mp3"))
        _ = try await deps.files.importFile(from: URL(fileURLWithPath: "/b.mp3"))
        deps.artwork.setCacheSize(4096)
        let model = deps.makeViewModel()
        #expect(model.librarySize == nil)

        await model.refreshSizes()

        #expect(model.librarySize == 2000)
        #expect(model.artworkCacheSize == 4096)
    }

    @Test func clearingArtworkEmptiesCacheAndKeepsKeys() async throws {
        let deps = TestDependencies()
        let key = try await deps.artwork.store(Data([1, 2, 3]))
        deps.artwork.setCacheSize(4096)
        let model = deps.makeViewModel()
        await model.refreshSizes()

        await model.clearArtworkCache()

        #expect(model.artworkCacheSize == 0)
        #expect(model.errorMessage == nil)
        #expect(!model.isClearingArtwork)
        // Keys stay resolvable: the store rebuilds the copies on demand.
        #expect(await deps.artwork.url(for: key, size: .thumbnail) != nil)
    }

    @Test func failedClearReportsError() async {
        let deps = TestDependencies()
        deps.artwork.setCacheSize(4096)
        deps.artwork.failClearing(true)
        let model = deps.makeViewModel()

        await model.clearArtworkCache()

        #expect(model.errorMessage == Strings.clearFailed)
        #expect(model.artworkCacheSize == 4096)
    }

    @Test func formatsSizes() {
        let english = Locale(identifier: "en_US")
        #expect(Strings.size(1_500_000, locale: english) == "1.5 MB")
        #expect(Strings.size(0, locale: english) == "0 bytes")
        #expect(Strings.size(2_000_000_000, locale: english) == "2 GB")
    }

    @Test func buildsVersionStringFromInfoDictionary() {
        let info = AppInfo(infoDictionary: [
            "CFBundleDisplayName": "Serya",
            "CFBundleName": "SeryaPlayer",
            "CFBundleShortVersionString": "1.2",
            "CFBundleVersion": "45",
        ])
        #expect(info.name == "Serya")
        #expect(info.versionString == "1.2 (45)")
    }

    @Test func infoFallsBackWhenKeysAreMissing() {
        let info = AppInfo(infoDictionary: ["CFBundleName": "SeryaPlayer"])
        #expect(info.name == "SeryaPlayer")
        #expect(info.versionString == "1.0 (1)")
        #expect(AppInfo(infoDictionary: nil).name == "SeryaPlayer")
    }
}
