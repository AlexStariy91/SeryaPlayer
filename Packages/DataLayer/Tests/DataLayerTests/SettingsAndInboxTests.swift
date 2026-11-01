@testable import DataLayer
import Domain
import Foundation
import Testing

struct UserDefaultsSettingsRepositoryTests {
    let suiteName = "DataLayerTests-\(UUID().uuidString)"

    @Test func loadsDefaultsSavesAndObserves() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        #expect(repository.load() == AppSettings())

        let stream = repository.observe()
        #expect(try await value(from: stream) == AppSettings())

        var settings = AppSettings(theme: .dark, accentColorID: "mint", librarySort: TrackSort(field: .artist, ascending: false))
        settings.equalizer.isEnabled = true
        repository.save(settings)

        #expect(try await value(from: stream) == settings)
        #expect(UserDefaultsSettingsRepository(defaults: defaults).load() == settings)
    }

    @Test func playbackRateSurvivesRelaunch() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var settings = AppSettings()
        #expect(settings.playbackRate == 1)
        settings.playbackRate = 1.5
        UserDefaultsSettingsRepository(defaults: defaults).save(settings)

        #expect(UserDefaultsSettingsRepository(defaults: defaults).load().playbackRate == 1.5)
    }

    @Test func settingsSavedBeforeTheRateExistedKeepEverythingElse() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var settings = AppSettings(theme: .dark, accentColorID: "mint")
        settings.equalizer.isEnabled = true
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        object["playbackRate"] = nil
        try defaults.set(JSONSerialization.data(withJSONObject: object), forKey: UserDefaultsSettingsRepository.defaultKey)

        #expect(UserDefaultsSettingsRepository(defaults: defaults).load() == settings)
    }

    @Test func corruptValueFallsBackToDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("garbage".utf8), forKey: UserDefaultsSettingsRepository.defaultKey)
        #expect(UserDefaultsSettingsRepository(defaults: defaults).load() == AppSettings())
    }
}

struct FilePlaybackStateRepositoryTests {
    @Test func savesAndLoadsState() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.cleanUp() }
        let repository = FilePlaybackStateRepository(fileURL: directory.url.appending(path: "Library/PlaybackState.json"))
        #expect(await repository.load() == nil)

        let ids = [UUID(), UUID()]
        let state = PlaybackState(queue: ids, originalQueue: ids.reversed(), currentIndex: 1, position: 42.5, isShuffled: true, repeatMode: .one)
        try await repository.save(state)
        #expect(await repository.load() == state)

        try Data("{".utf8).write(to: repository.fileURL)
        #expect(await repository.load() == nil)
    }
}

/// Files the importer was handed, for assertions from the `@Sendable` closure.
actor ImportLog {
    private(set) var batches: [[String]] = []

    func record(_ urls: [URL]) {
        batches.append(urls.map(\.lastPathComponent).sorted())
    }
}

struct InboxProcessorTests {
    @Test func importsPendingFilesAndKeepsOnlyFailedOnes() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.cleanUp() }
        let store = FileStore(rootURL: directory.url.appending(path: "Library"), documentsInboxURL: directory.url.appending(path: "Documents/Inbox"))
        _ = await store.pendingInboxFiles() // creates both inboxes
        try Data("1".utf8).write(to: store.inboxURL.appending(path: "good.mp3"))
        try Data("2".utf8).write(to: store.documentsInboxURL.appending(path: "dup.m4a"))
        try Data("3".utf8).write(to: store.documentsInboxURL.appending(path: "broken.flac"))
        let log = ImportLog()

        let processor = InboxProcessor(fileStore: store) { urls in
            await log.record(urls)
            return ImportResult(added: [], duplicates: ["dup.m4a"], unsupported: [], failed: ["broken.flac"])
        }
        let result = await processor.process()

        #expect(result.failed == ["broken.flac"])
        #expect(await log.batches == [["broken.flac", "dup.m4a", "good.mp3"]])
        #expect(await store.pendingInboxFiles().map(\.lastPathComponent) == ["broken.flac"])
    }

    @Test func emptyInboxDoesNotCallImporter() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.cleanUp() }
        let store = FileStore(rootURL: directory.url, documentsInboxURL: directory.url.appending(path: "Docs"))
        let log = ImportLog()
        let processor = InboxProcessor(fileStore: store) { urls in
            await log.record(urls)
            return ImportResult()
        }

        #expect(await processor.process() == ImportResult())
        #expect(await log.batches.isEmpty)
    }
}

struct UserDefaultsTrackPositionRepositoryTests {
    let suiteName = "DataLayerTests-\(UUID().uuidString)"

    @Test func savesReadsAndRemovesPositions() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UserDefaultsTrackPositionRepository(defaults: defaults)
        let first = UUID(), second = UUID()
        #expect(repository.position(for: first) == nil)

        repository.save(position: 123.5, for: first)
        repository.save(position: 900, for: second)
        #expect(UserDefaultsTrackPositionRepository(defaults: defaults).position(for: first) == 123.5)

        repository.save(position: 200, for: first)
        #expect(repository.position(for: first) == 200)

        repository.remove(trackIDs: [first, UUID()])
        #expect(repository.position(for: first) == nil)
        #expect(repository.position(for: second) == 900)
    }
}
