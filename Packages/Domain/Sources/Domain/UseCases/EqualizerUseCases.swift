import Foundation

/// Built-in presets followed by the user's, as one stream.
public struct ObserveEQPresetsUseCase: Sendable {
    private let presets: any EQPresetRepository

    public init(presets: any EQPresetRepository) {
        self.presets = presets
    }

    public func callAsFunction() -> AsyncStream<[EQPreset]> {
        let user = presets.observePresets()
        return AsyncStream { continuation in
            let task = Task {
                for await list in user {
                    continuation.yield(BuiltInPresets.all + list)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Applies a preset to the saved settings: gains, preamp and `presetID`; turns the equalizer on.
public struct ApplyEQPresetUseCase: Sendable {
    private let settings: any SettingsRepository

    public init(settings: any SettingsRepository) {
        self.settings = settings
    }

    @discardableResult
    public func callAsFunction(_ preset: EQPreset) -> EQSettings {
        var current = settings.load()
        current.equalizer.isEnabled = true
        current.equalizer.gains = EqualizerMath.normalized(preset.gains)
        current.equalizer.preamp = preset.preamp
        current.equalizer.presetID = preset.id
        settings.save(current)
        return current.equalizer
    }
}

/// Manual band edit. Any edit detaches from the preset: the result is an unsaved "Custom"
/// (`presetID == nil`), so a built-in preset is never modified. The preamp follows the auto rule.
public struct EditEQBandUseCase: Sendable {
    private let settings: any SettingsRepository

    public init(settings: any SettingsRepository) {
        self.settings = settings
    }

    @discardableResult
    public func callAsFunction(band: Int, gain: Float) -> EQSettings {
        var current = settings.load()
        var gains = EqualizerMath.normalized(current.equalizer.gains)
        if gains.indices.contains(band) {
            gains[band] = EqualizerMath.clamp(gain)
        }
        current.equalizer.gains = gains
        current.equalizer.preamp = EqualizerMath.autoPreamp(for: gains)
        current.equalizer.presetID = nil
        settings.save(current)
        return current.equalizer
    }
}

public struct SaveEQPresetUseCase: Sendable {
    private let presets: any EQPresetRepository
    private let settings: any SettingsRepository

    public init(presets: any EQPresetRepository, settings: any SettingsRepository) {
        self.presets = presets
        self.settings = settings
    }

    /// Saves the current equalizer curve as a user preset and makes it the active one.
    @discardableResult
    public func callAsFunction(name: String) async throws -> EQPreset {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.emptyName }
        var current = settings.load()
        let preset = EQPreset(
            name: trimmed,
            gains: EqualizerMath.normalized(current.equalizer.gains),
            preamp: current.equalizer.preamp
        )
        try await presets.save(preset)
        current.equalizer.presetID = preset.id
        settings.save(current)
        return preset
    }
}

public struct DeleteEQPresetUseCase: Sendable {
    private let presets: any EQPresetRepository
    private let settings: any SettingsRepository

    public init(presets: any EQPresetRepository, settings: any SettingsRepository) {
        self.presets = presets
        self.settings = settings
    }

    /// Built-in presets cannot be deleted. If the preset was active, the curve stays as an unsaved "Custom".
    public func callAsFunction(_ preset: EQPreset) async throws {
        guard !preset.isBuiltIn else { return }
        try await presets.delete(id: preset.id)
        var current = settings.load()
        if current.equalizer.presetID == preset.id {
            current.equalizer.presetID = nil
            settings.save(current)
        }
    }
}
