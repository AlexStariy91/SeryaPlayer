import Domain
import SwiftUI

/// Everything the equalizer needs. `AppContainer` conforms; property names match the container's.
@MainActor
public protocol EqualizerDependencies {
    var presetRepository: any EQPresetRepository { get }
    /// The current curve lives in `AppSettings.equalizer`.
    var settingsRepository: any SettingsRepository { get }
    /// Receives every change through `apply(_:)`.
    var player: any PlaybackControlling { get }
}

public enum EqualizerFeature {
    /// The sheet the player presents. Detents `.medium` (presets, curve, on/off) and `.large` (plus band sliders and preamp).
    @MainActor
    public static func makeSheet(dependencies: some EqualizerDependencies) -> some View {
        EqualizerSheet(viewModel: EqualizerViewModel(dependencies: dependencies))
    }

    /// A list of the user's presets (rename, delete, import, export) to embed in Settings.
    @MainActor
    public static func makePresetManager(dependencies: some EqualizerDependencies) -> some View {
        PresetManagerView(viewModel: EqualizerViewModel(dependencies: dependencies))
    }
}
