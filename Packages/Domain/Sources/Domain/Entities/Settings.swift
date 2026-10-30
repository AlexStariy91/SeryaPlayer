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

    public init(
        theme: AppTheme = .system,
        accentColorID: String = "serya",
        librarySort: TrackSort = TrackSort(),
        equalizer: EQSettings = EQSettings()
    ) {
        self.theme = theme
        self.accentColorID = accentColorID
        self.librarySort = librarySort
        self.equalizer = equalizer
    }
}
