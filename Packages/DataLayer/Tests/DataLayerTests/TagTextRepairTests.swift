@testable import DataLayer
import Domain
import Foundation
import Testing

/// `text` written as Windows-1251 and read back as strict Latin-1, the way AVFoundation reads such ID3 frames.
func cp1251AsLatin1(_ text: String) -> String {
    String(bytes: text.data(using: .windowsCP1251)!, encoding: .isoLatin1)!
}

struct TagTextRepairTests {
    static let russian = [
        "Любовь и Мир", "Тимати", "Артем Меладзе", "Инна Маликова", "Звезда по имени Солнце",
        "Ёлка", "Это всё", "Мы", "Ой, мама!", "Ночь — «тест» №1…", "Пачка сигарет (Live)",
        "ДДТ", "Сплин - Выхода нет", "Україна", "Їжак і ґанок", "Беларусь",
    ]

    @Test(arguments: russian)
    func repairsWindows1251ReadAsLatin1(original: String) {
        let mojibake = cp1251AsLatin1(original)
        #expect(mojibake != original)
        #expect(TagTextRepair.repaired(mojibake) == original)
    }

    @Test func repairsTheReportedExamples() {
        #expect(TagTextRepair.repair("Òèìàòè") == "Тимати")
        #expect(TagTextRepair.repair("Àðòåì Ìåëàäçå") == "Артем Меладзе")
        #expect(TagTextRepair.repair("Ëþáîâü è Ìèð") == "Любовь и Мир")
    }

    @Test(arguments: [
        "Элджей feat. Feduk", "Баста - Сансара (feat. Скриптонит)", "DJ Smash & Глюкоза", "Ленинград — WWW",
        "Сектор Газа 1990", "Би-2", "t.A.T.u. - Я сошла с ума", "Мумий Тролль: Moscow Calling",
    ])
    func repairsMojibakeMixedWithLatinWords(original: String) {
        #expect(TagTextRepair.repaired(cp1251AsLatin1(original)) == original)
    }

    @Test func repairsWindows1252ReadingOfPunctuation() throws {
        // Read as Windows-1252, 0x97 becomes "—" instead of the control character U+0097.
        let bytes = try #require("Сплин — Романс".data(using: .windowsCP1251))
        let windows1252 = try #require(String(bytes: bytes, encoding: .windowsCP1252))
        #expect(windows1252.contains("—"))
        #expect(TagTextRepair.repaired(windows1252) == "Сплин — Романс")
    }

    @Test func repairsUTF8ReadAsLatin1() throws {
        let mojibake = try #require(String(bytes: Array("Тимати".utf8), encoding: .isoLatin1))
        #expect(TagTextRepair.repaired(mojibake) == "Тимати")
        let accented = try #require(String(bytes: Array("Beyoncé".utf8), encoding: .isoLatin1))
        #expect(TagTextRepair.repaired(accented) == "Beyoncé")
    }

    @Test(arguments: [
        "Beyoncé", "Mötley Crüe", "Café del Mar", "Sigur Rós", "Björk", "Motörhead", "Hôtel Costes",
        "Canción del Mariachi", "¿Quién será?", "Les Feuilles mortes à Paris", "Ça plane pour moi",
        "Straße der Ölsardinen", "Être et Avoir", "Où est la plage", "Ø", "Å", "É", "Ålesund",
        "Pokémon – Theme", "Don’t Stop", "AC/DC ©1980", "50 °C", "½ Moon", "Daft Punk × Pharrell",
        "Été Indien", "ÉTÉ", "MÖTLEY CRÜE", "Garçon", "Señorita", "Smörgåsbord", "Œuvre",
    ])
    func keepsGenuineLatinText(text: String) {
        #expect(TagTextRepair.repaired(text) == nil)
        #expect(TagTextRepair.repair(text) == text)
    }

    @Test(arguments: [
        "Инна Маликова", "Элджей- Feduk", "Тимати", "Ёлка", "東京事変", "Ελληνικά", "Hello, World", "", " ", "2024",
        "Rock'n'Roll", "AC/DC",
    ])
    func keepsCorrectUnicodeAndASCII(text: String) {
        #expect(TagTextRepair.repaired(text) == nil)
    }

    @Test func keepsSingleLetterAmbiguity() {
        // "ß" is "Я" in Windows-1251, but also a German letter on its own; too short to decide.
        #expect(TagTextRepair.repaired(cp1251AsLatin1("Я")) == nil)
        #expect(TagTextRepair.repaired(cp1251AsLatin1("Ты и я")) == "Ты и я")
    }

    @Test func isIdempotent() {
        for original in Self.russian {
            let once = TagTextRepair.repair(cp1251AsLatin1(original))
            #expect(TagTextRepair.repair(once) == once)
        }
    }

    @Test func rejectsControlCharacters() {
        #expect(TagTextRepair.repaired("\u{01}Òèìàòè") == nil)
        // 0x98 is unassigned in Windows-1251.
        #expect(TagTextRepair.repaired("Òèì\u{98}àòè") == nil)
    }
}

struct TagTextReaderTests {
    @Test func repairsID3v2LatinFrames() async throws {
        let metadata = try await MetadataReader().read(from: MetadataReaderTests.fixture("cp1251-id3v2.mp3"))
        #expect(metadata.title == "Любовь и Мир")
        #expect(metadata.artist == "Тимати")
        #expect(metadata.album == "Артем Меладзе")
        #expect(metadata.trackNumber == 5)
    }

    @Test func repairsID3v1Tag() async throws {
        let metadata = try await MetadataReader().read(from: MetadataReaderTests.fixture("cp1251-id3v1.mp3"))
        #expect(metadata.title == "Звезда")
        #expect(metadata.artist == "Кино")
        #expect(metadata.album == "Группа крови")
        #expect(metadata.trackNumber == 7)
    }
}

struct TagTextMigrationTests {
    let persistence: PersistenceController
    let tracks: CoreDataTrackRepository
    let suiteName = "DataLayerTests-\(UUID().uuidString)"

    init() throws {
        persistence = try PersistenceController(store: .inMemory)
        tracks = CoreDataTrackRepository(persistence: persistence, observationInterval: .zero)
    }

    @Test func repairsStoredTracksInPlace() async throws {
        var broken = makeTrack(title: cp1251AsLatin1("Любовь и Мир"), artist: cp1251AsLatin1("Тимати"), album: cp1251AsLatin1("Мир"))
        broken.albumArtist = cp1251AsLatin1("Тимати")
        let correct = makeTrack(title: "Лето", artist: "Тимати", album: "Мир")
        let latin = makeTrack(title: "Halo", artist: "Beyoncé", album: "Café del Mar")
        try await tracks.add([broken, correct, latin])
        try await tracks.markPlayed(id: broken.id, at: .now)

        let playlists = CoreDataPlaylistRepository(persistence: persistence)
        let playlist = Playlist(name: "Mix")
        try await playlists.create(playlist)
        try await playlists.append(trackIDs: [broken.id, latin.id], to: playlist.id)

        let migration = TagTextMigration(persistence: persistence)
        #expect(try await migration.run() == 1)

        let stored = try await tracks.tracks(ids: [broken.id])
        let fixed = try #require(stored.first)
        #expect(fixed.title == "Любовь и Мир")
        #expect(fixed.artist == "Тимати")
        #expect(fixed.album == "Мир")
        #expect(fixed.albumArtist == "Тимати")
        #expect(fixed.playCount == 1)
        #expect(fixed.relativePath == broken.relativePath)
        // Same artist and album text as the correctly tagged track: they group together.
        #expect(fixed.artist == correct.artist && fixed.album == correct.album)
        #expect(try await tracks.tracks(ids: [correct.id, latin.id]) == [correct, latin])

        let entries = try await value(from: playlists.observeEntries(of: playlist.id)) { $0.count == 2 }
        #expect(entries.map(\.trackID) == [broken.id, latin.id])

        // Safe to run again: nothing left to repair.
        #expect(try await migration.run() == 0)
    }

    @Test func runsOncePerVersion() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let migration = TagTextMigration(persistence: persistence, defaults: defaults)

        try await tracks.add([makeTrack(title: cp1251AsLatin1("Тимати"))])
        #expect(try await migration.runIfNeeded() == 1)
        #expect(defaults.integer(forKey: TagTextMigration.defaultKey) == TagTextMigration.version)

        try await tracks.add([makeTrack(title: cp1251AsLatin1("Кино"))])
        #expect(try await migration.runIfNeeded() == 0)
    }

    @Test func notifiesObservers() async throws {
        let track = makeTrack(title: cp1251AsLatin1("Тимати"))
        try await tracks.add([track])
        let stream = tracks.observeTracks(sortedBy: TrackSort())
        _ = try await value(from: stream) { $0.first?.title == track.title }

        try await TagTextMigration(persistence: persistence).run()
        _ = try await value(from: stream) { $0.first?.title == "Тимати" }
    }
}
