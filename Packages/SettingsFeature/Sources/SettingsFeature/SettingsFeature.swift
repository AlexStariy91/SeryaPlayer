import Domain
import SwiftUI

/// Everything Settings needs. `AppContainer` conforms; property names match the container's.
@MainActor
public protocol SettingsDependencies {
    /// Theme and accent are only persisted here; the app observes the repository and applies them.
    var settingsRepository: any SettingsRepository { get }
    /// Source of the library size.
    var fileStore: any FileStoring { get }
    /// Source of the artwork cache size and the way to clear it.
    var artworkStore: any ArtworkStoring { get }
}

public enum SettingsFeature {
    /// The settings screen, meant to be presented as a sheet; "Done" dismisses it through the environment.
    /// `presetManager` is pushed from the "Equalizer" row (`EqualizerFeature.makePresetManager`).
    @MainActor
    public static func makeRootView(
        dependencies: some SettingsDependencies,
        @ViewBuilder presetManager: @escaping () -> some View
    ) -> some View {
        SettingsView(viewModel: SettingsViewModel(dependencies: dependencies), presetManager: presetManager)
    }
}
