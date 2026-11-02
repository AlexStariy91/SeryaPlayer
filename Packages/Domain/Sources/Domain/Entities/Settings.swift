import Foundation

public enum AppTheme: String, CaseIterable, Sendable, Codable {
    case system, light, dark
}

public struct AppSettings: Sendable, Equatable, Codable {
    public var theme: AppTheme
    /// Accent ID from the DesignSystem palette. Defaults to the brand color #1C283F.
    public var accentColorID: String
    public var librarySort: TrackSort
    public var equalizer: EQSettings
    /// Global playback speed, one of `PlaybackRate.options`. Applies to every track.
    public var playbackRate: Float
    /// The full player shows the spectrum visualizer instead of the artwork.
    public var showsVisualizer: Bool

    public init(
        theme: AppTheme = .system,
        accentColorID: String = "serya",
        librarySort: TrackSort = TrackSort(),
        equalizer: EQSettings = EQSettings(),
        playbackRate: Float = PlaybackRate.normal,
        showsVisualizer: Bool = false
    ) {
        self.theme = theme
        self.accentColorID = accentColorID
        self.librarySort = librarySort
        self.equalizer = equalizer
        self.playbackRate = playbackRate
        self.showsVisualizer = showsVisualizer
    }

    /// Keys missing from settings saved by an older version take their defaults, so adding a setting
    /// never resets the others.
    public init(from decoder: any Decoder) throws {
        let defaults = AppSettings()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? defaults.theme
        accentColorID = try container.decodeIfPresent(String.self, forKey: .accentColorID) ?? defaults.accentColorID
        librarySort = try container.decodeIfPresent(TrackSort.self, forKey: .librarySort) ?? defaults.librarySort
        equalizer = try container.decodeIfPresent(EQSettings.self, forKey: .equalizer) ?? defaults.equalizer
        playbackRate = try container.decodeIfPresent(Float.self, forKey: .playbackRate) ?? defaults.playbackRate
        showsVisualizer = try container.decodeIfPresent(Bool.self, forKey: .showsVisualizer) ?? defaults.showsVisualizer
    }
}
