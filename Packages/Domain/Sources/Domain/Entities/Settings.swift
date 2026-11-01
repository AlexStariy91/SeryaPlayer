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

    public init(
        theme: AppTheme = .system,
        accentColorID: String = "serya",
        librarySort: TrackSort = TrackSort(),
        equalizer: EQSettings = EQSettings(),
        playbackRate: Float = PlaybackRate.normal
    ) {
        self.theme = theme
        self.accentColorID = accentColorID
        self.librarySort = librarySort
        self.equalizer = equalizer
        self.playbackRate = playbackRate
    }

    /// Settings saved by an older version have no `playbackRate`; it falls back to normal speed.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decode(AppTheme.self, forKey: .theme)
        accentColorID = try container.decode(String.self, forKey: .accentColorID)
        librarySort = try container.decode(TrackSort.self, forKey: .librarySort)
        equalizer = try container.decode(EQSettings.self, forKey: .equalizer)
        playbackRate = try container.decodeIfPresent(Float.self, forKey: .playbackRate) ?? PlaybackRate.normal
    }
}
