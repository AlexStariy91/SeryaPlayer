import Domain
import DomainTestSupport
import Foundation
import Testing

struct EqualizerUseCaseTests {
    @Test func applyingPresetUpdatesSettings() {
        let settings = InMemorySettingsRepository()
        let rock = BuiltInPresets.all[1]
        let applied = ApplyEQPresetUseCase(settings: settings)(rock)
        #expect(applied.isEnabled)
        #expect(applied.gains == rock.gains)
        #expect(applied.preamp == rock.preamp)
        #expect(applied.presetID == rock.id)
        #expect(settings.load().equalizer == applied)
    }

    @Test func editingBuiltInPresetBecomesUnsavedCustom() {
        let settings = InMemorySettingsRepository()
        ApplyEQPresetUseCase(settings: settings)(BuiltInPresets.all[1])
        let edited = EditEQBandUseCase(settings: settings)(band: 0, gain: 20)
        #expect(edited.presetID == nil)
        #expect(edited.gains[0] == 12)
        #expect(edited.preamp == -12)
        #expect(BuiltInPresets.all[1].gains[0] == 5)
    }

    @Test func editingOutOfRangeBandIsIgnored() {
        let settings = InMemorySettingsRepository()
        let edited = EditEQBandUseCase(settings: settings)(band: 42, gain: 5)
        #expect(edited.gains == Array(repeating: 0, count: EQBands.count))
    }

    @Test func savingStoresCurrentCurveAndActivatesIt() async throws {
        let settings = InMemorySettingsRepository()
        let presets = InMemoryEQPresetRepository()
        EditEQBandUseCase(settings: settings)(band: 2, gain: 4)
        let saved = try await SaveEQPresetUseCase(presets: presets, settings: settings)(name: " Mine ")
        #expect(saved.name == "Mine")
        #expect(!saved.isBuiltIn)
        #expect(saved.gains[2] == 4)
        #expect(saved.preamp == -4)
        #expect(presets.snapshot == [saved])
        #expect(settings.load().equalizer.presetID == saved.id)
    }

    @Test func savingRejectsBlankName() async {
        let save = SaveEQPresetUseCase(presets: InMemoryEQPresetRepository(), settings: InMemorySettingsRepository())
        await #expect(throws: DomainError.emptyName) { try await save(name: " ") }
    }

    @Test func deletingActivePresetDetachesIt() async throws {
        let settings = InMemorySettingsRepository()
        let presets = InMemoryEQPresetRepository()
        let saved = try await SaveEQPresetUseCase(presets: presets, settings: settings)(name: "Mine")
        try await DeleteEQPresetUseCase(presets: presets, settings: settings)(saved)
        #expect(presets.snapshot.isEmpty)
        #expect(settings.load().equalizer.presetID == nil)
    }

    @Test func builtInPresetCannotBeDeleted() async throws {
        let presets = InMemoryEQPresetRepository()
        try await DeleteEQPresetUseCase(presets: presets, settings: InMemorySettingsRepository())(BuiltInPresets.all[0])
        #expect(presets.snapshot.isEmpty)
    }

    @Test func observeListsBuiltInsThenUserPresets() async {
        let mine = EQPreset(name: "Mine", gains: Array(repeating: 0, count: EQBands.count))
        let presets = InMemoryEQPresetRepository(presets: [mine])
        var iterator = ObserveEQPresetsUseCase(presets: presets)().makeAsyncIterator()
        let list = await iterator.next()
        #expect(list?.count == 17)
        #expect(list?.first?.name == "Flat")
        #expect(list?.last == mine)
    }
}
