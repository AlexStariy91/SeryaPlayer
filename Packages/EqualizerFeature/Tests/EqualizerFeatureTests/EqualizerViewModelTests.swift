import Domain
import DomainTestSupport
@testable import EqualizerFeature
import Foundation
import Testing

@MainActor
struct EqualizerViewModelTests {
    @Test func startsOnFlatWhenGainsAreZero() {
        let viewModel = TestDependencies().makeViewModel()
        #expect(viewModel.selectedPreset?.id == BuiltInPresets.flat.id)
        #expect(!viewModel.isCustom)
    }

    @Test func selectingPresetAppliesPersistsAndEnables() throws {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()
        let rock = try #require(BuiltInPresets.all.first { $0.name == "Rock" })

        viewModel.select(rock)

        #expect(viewModel.selectedPreset?.id == rock.id)
        #expect(deps.equalizer.gains == rock.gains)
        #expect(deps.equalizer.presetID == rock.id)
        #expect(deps.equalizer.isEnabled)
        #expect(deps.playback.appliedEqualizers.last == deps.equalizer)
    }

    @Test func editingBandBecomesCustomWithAutoPreamp() {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()

        viewModel.setGain(band: 3, gain: 6)

        #expect(viewModel.isCustom)
        #expect(viewModel.settings.gains[3] == 6)
        #expect(viewModel.settings.preamp == -6)
        #expect(deps.equalizer.gains[3] == 6)
        #expect(deps.playback.appliedEqualizers.last?.gains[3] == 6)
    }

    @Test func gainsAreClampedAndUnchangedGainsAreNotReapplied() {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()

        viewModel.setGain(band: 0, gain: 40)
        #expect(viewModel.settings.gains[0] == 12)

        let count = deps.playback.appliedEqualizers.count
        viewModel.setGain(band: 0, gain: 12)
        viewModel.setGain(band: 99, gain: 1)
        #expect(deps.playback.appliedEqualizers.count == count)
    }

    @Test func returningToPresetGainsLeavesCustom() throws {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()
        let rock = try #require(BuiltInPresets.all.first { $0.name == "Rock" })
        viewModel.select(rock)
        viewModel.setGain(band: 0, gain: 0)
        #expect(viewModel.isCustom)

        viewModel.setGain(band: 0, gain: rock.gains[0])
        #expect(viewModel.selectedPreset?.id == rock.id)
    }

    @Test func preampAndToggleAreAppliedAndPersisted() {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()

        viewModel.setPreamp(-4)
        viewModel.setEnabled(true)

        #expect(deps.equalizer.preamp == -4)
        #expect(deps.equalizer.isEnabled)
        #expect(deps.playback.appliedEqualizers.last == deps.equalizer)

        viewModel.setEnabled(false)
        #expect(!deps.equalizer.isEnabled)
        #expect(deps.playback.appliedEqualizers.last?.isEnabled == false)
    }

    @Test func saveCurrentCreatesUserPresetAndSelectsIt() async throws {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()
        viewModel.setGain(band: 1, gain: 5)

        await viewModel.saveCurrent(as: "  Warm  ")
        await viewModel.loadPresets(from: deps)

        let saved = try #require(deps.presets.snapshot.first)
        #expect(saved.name == "Warm")
        #expect(saved.gains[1] == 5)
        #expect(viewModel.selectedPreset?.id == saved.id)
        #expect(viewModel.userPresets.map(\.name) == ["Warm"])
        #expect(viewModel.errorMessage == nil)
    }

    @Test func saveWithEmptyNameReportsError() async {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()

        await viewModel.saveCurrent(as: "   ")

        #expect(deps.presets.snapshot.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func renameUpdatesNameOnly() async throws {
        let preset = EQPreset(name: "Old", gains: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0], preamp: -1)
        let deps = TestDependencies(userPresets: [preset])
        let viewModel = deps.makeViewModel()

        await viewModel.rename(preset, to: " New ")

        let stored = try #require(deps.presets.snapshot.first)
        #expect(stored.id == preset.id)
        #expect(stored.name == "New")
        #expect(stored.gains == preset.gains)

        await viewModel.rename(preset, to: "")
        #expect(viewModel.errorMessage != nil)
        #expect(deps.presets.snapshot.first?.name == "New")
    }

    @Test func deleteRemovesPresetAndFallsBackToCustom() async {
        let preset = EQPreset(name: "Mine", gains: [2, 2, 0, 0, 0, 0, 0, 0, 0, 0], preamp: -2)
        let deps = TestDependencies(userPresets: [preset])
        let viewModel = deps.makeViewModel()
        await viewModel.loadPresets(from: deps)
        viewModel.select(preset)
        #expect(viewModel.selectedPreset?.id == preset.id)

        await viewModel.delete(preset)
        await viewModel.loadPresets(from: deps)

        #expect(deps.presets.snapshot.isEmpty)
        #expect(viewModel.userPresets.isEmpty)
        #expect(deps.equalizer.presetID == nil)
        #expect(viewModel.isCustom)
    }

    @Test func builtInPresetsCannotBeDeleted() async {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()
        viewModel.select(BuiltInPresets.all[1])

        await viewModel.delete(BuiltInPresets.all[1])

        #expect(viewModel.selectedPreset?.id == BuiltInPresets.all[1].id)
    }

    @Test func exportImportRoundTrip() async throws {
        let source = [
            EQPreset(name: "A", gains: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], preamp: -10),
            EQPreset(name: "B", gains: [-3, 0, 0, 0, 0, 0, 0, 0, 0, 3], preamp: -3),
        ]
        let sender = TestDependencies(userPresets: source).makeViewModel()
        let data = try sender.exportFile(for: source).data()

        let receiverDeps = TestDependencies()
        let receiver = receiverDeps.makeViewModel()
        try await receiver.importPresets(from: data)

        let imported = receiverDeps.presets.snapshot
        #expect(imported.map(\.name) == ["A", "B"])
        #expect(imported.map(\.gains) == source.map(\.gains))
        #expect(imported.map(\.preamp) == source.map(\.preamp))
        #expect(Set(imported.map(\.id)).isDisjoint(with: source.map(\.id)))
        #expect(imported.allSatisfy { !$0.isBuiltIn })
    }

    @Test func importNormalizesAndRejectsGarbage() throws {
        let json = #"{"version":1,"presets":[{"name":"Loud","gains":[50,-50],"preamp":99},{"name":" ","gains":[],"preamp":0}]}"#
        let presets = try PresetFile.presets(from: Data(json.utf8))
        #expect(presets.count == 1)
        #expect(presets[0].gains == [12, -12, 0, 0, 0, 0, 0, 0, 0, 0])
        #expect(presets[0].preamp == 12)

        #expect(throws: PresetFileError.self) { try PresetFile.presets(from: Data("nope".utf8)) }
        #expect(throws: PresetFileError.self) { try PresetFile.presets(from: Data(#"{"version":9,"presets":[]}"#.utf8)) }
    }

    @Test func importingFromUnreadableFileReportsError() async {
        let viewModel = TestDependencies().makeViewModel()
        await viewModel.importPresets(from: [URL(fileURLWithPath: "/nonexistent/file.seryaeq")])
        #expect(viewModel.errorMessage != nil)
    }

    @Test func continuousEditAppliesEveryValueButPersistsOnce() {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()
        let applied = deps.playback.appliedEqualizers.count

        viewModel.setEditing(true)
        for gain in stride(from: Float(1), through: 8, by: 1) {
            viewModel.setGain(band: 2, gain: gain)
        }
        #expect(deps.settings.saveCount == 0)
        #expect(deps.playback.appliedEqualizers.count - applied == 8)
        #expect(deps.playback.appliedEqualizers.last?.gains[2] == 8)
        #expect(deps.playback.appliedEqualizers.last?.preamp == -8)

        viewModel.setEditing(false)
        #expect(deps.settings.saveCount == 1)
        #expect(deps.equalizer.gains[2] == 8)
        #expect(deps.equalizer.preamp == -8)
        #expect(deps.equalizer.presetID == nil)
        #expect(viewModel.isCustom)
    }

    @Test func settingsEchoDuringEditDoesNotOverwriteLocalValue() async {
        let deps = TestDependencies()
        let viewModel = deps.makeViewModel()
        let follower = Task { await viewModel.start() }
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        viewModel.setEditing(true)
        viewModel.setGain(band: 0, gain: 9)
        var stale = deps.settings.load()
        stale.equalizer.gains[0] = 3
        deps.settings.save(stale)
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(viewModel.settings.gains[0] == 9)

        viewModel.setEditing(false)
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        follower.cancel()
        #expect(viewModel.settings.gains[0] == 9)
        #expect(deps.equalizer.gains[0] == 9)
    }
}
