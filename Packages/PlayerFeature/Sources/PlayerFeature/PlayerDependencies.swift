import Domain

/// What the player needs from the Composition Root. `AppContainer` conforms to it.
@MainActor
public protocol PlayerDependencies {
    var player: any PlaybackControlling { get }
    var artworkStore: any ArtworkStoring { get }
    /// Read for the "equalizer on" indicator on the EQ button.
    var settingsRepository: any SettingsRepository { get }
}
