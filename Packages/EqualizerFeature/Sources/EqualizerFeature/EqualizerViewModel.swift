import Domain
import Foundation
import Observation

/// Drives both the sheet and the preset manager. Every change goes through the Domain use cases
/// (which persist into `AppSettings.equalizer`) and is then pushed to the player.
@MainActor
@Observable
final class EqualizerViewModel {
    private(set) var settings: EQSettings
    /// Built-in presets followed by the user's.
    private(set) var presets: [EQPreset] = BuiltInPresets.all
    var errorMessage: String?

    private let presetRepository: any EQPresetRepository
    private let settingsRepository: any SettingsRepository
    private let player: any PlaybackControlling
    private let applyPreset: ApplyEQPresetUseCase
    private let editBand: EditEQBandUseCase
    private let savePreset: SaveEQPresetUseCase
    private let deletePreset: DeleteEQPresetUseCase
    private let observePresets: ObserveEQPresetsUseCase

    init(dependencies: some EqualizerDependencies) {
        presetRepository = dependencies.presetRepository
        settingsRepository = dependencies.settingsRepository
        player = dependencies.player
        applyPreset = ApplyEQPresetUseCase(settings: settingsRepository)
        editBand = EditEQBandUseCase(settings: settingsRepository)
        savePreset = SaveEQPresetUseCase(presets: presetRepository, settings: settingsRepository)
        deletePreset = DeleteEQPresetUseCase(presets: presetRepository, settings: settingsRepository)
        observePresets = ObserveEQPresetsUseCase(presets: presetRepository)
        settings = settingsRepository.load().equalizer
    }

    // MARK: - State

    var userPresets: [EQPreset] {
        presets.filter { !$0.isBuiltIn }
    }

    /// The preset the curve matches: the active one if its gains still match, otherwise any preset with the same gains.
    /// `nil` means "Custom".
    var selectedPreset: EQPreset? {
        if let id = settings.presetID, let active = presets.first(where: { $0.id == id }), Self.matches(active, settings.gains) {
            return active
        }
        return presets.first { Self.matches($0, settings.gains) }
    }

    var isCustom: Bool {
        selectedPreset == nil
    }

    private static func matches(_ preset: EQPreset, _ gains: [Float]) -> Bool {
        let normalized = EqualizerMath.normalized(gains)
        return zip(EqualizerMath.normalized(preset.gains), normalized).allSatisfy { abs($0 - $1) < 0.01 }
    }

    /// Runs until cancelled; keeps the preset list and settings in sync with storage.
    func start() async {
        async let presetUpdates: Void = followPresets()
        async let settingsUpdates: Void = followSettings()
        _ = await (presetUpdates, settingsUpdates)
    }

    private func followPresets() async {
        for await list in observePresets() {
            presets = list
        }
    }

    private func followSettings() async {
        for await updated in settingsRepository.observe() where updated.equalizer != settings {
            settings = updated.equalizer
        }
    }

    // MARK: - Editing

    func select(_ preset: EQPreset) {
        commit(applyPreset(preset))
    }

    func setGain(band: Int, gain: Float) {
        guard settings.gains.indices.contains(band), settings.gains[band] != EqualizerMath.clamp(gain) else { return }
        commit(editBand(band: band, gain: gain))
    }

    func setPreamp(_ preamp: Float) {
        var current = settingsRepository.load()
        current.equalizer.preamp = EqualizerMath.clamp(preamp)
        settingsRepository.save(current)
        commit(current.equalizer)
    }

    func setEnabled(_ isEnabled: Bool) {
        var current = settingsRepository.load()
        current.equalizer.isEnabled = isEnabled
        settingsRepository.save(current)
        commit(current.equalizer)
    }

    private func commit(_ equalizer: EQSettings) {
        settings = equalizer
        player.apply(equalizer)
    }

    // MARK: - User presets

    func saveCurrent(as name: String) async {
        await run {
            let preset = try await savePreset(name: name)
            settings.presetID = preset.id
        }
    }

    func rename(_ preset: EQPreset, to name: String) async {
        await run {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw DomainError.emptyName }
            guard !preset.isBuiltIn else { return }
            var renamed = preset
            renamed.name = trimmed
            try await presetRepository.save(renamed)
        }
    }

    func delete(_ preset: EQPreset) async {
        await run {
            try await deletePreset(preset)
            settings = settingsRepository.load().equalizer
        }
    }

    // MARK: - Export / import

    func exportFile(for presets: [EQPreset]) -> PresetFile {
        PresetFile(presets: presets)
    }

    /// Imports every readable file; a file that isn't a preset file reports an error but doesn't stop the others.
    func importPresets(from urls: [URL]) async {
        for url in urls {
            let isScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                try await importPresets(from: Data(contentsOf: url))
            } catch {
                errorMessage = Strings.message(for: PresetFileError())
            }
        }
    }

    func importPresets(from data: Data) async throws {
        for preset in try PresetFile.presets(from: data) {
            try await presetRepository.save(preset)
        }
    }

    private func run(_ work: () async throws -> Void) async {
        do {
            try await work()
        } catch {
            errorMessage = Strings.message(for: error)
        }
    }
}
