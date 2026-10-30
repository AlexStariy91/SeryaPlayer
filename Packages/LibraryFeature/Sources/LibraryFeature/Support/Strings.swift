import Domain
import Foundation

/// Display strings shared by several screens. Literal keys live in `Resources/Localizable.xcstrings`.
enum Strings {
    static func artist(_ name: String) -> String {
        name.isEmpty ? String(localized: "Unknown Artist", bundle: .module) : name
    }

    static func album(_ name: String) -> String {
        name.isEmpty ? String(localized: "Unknown Album", bundle: .module) : name
    }

    /// "Artist · Album" with unknown parts skipped.
    static func subtitle(for track: Track) -> String {
        [track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    static func songCount(_ count: Int) -> String {
        String(localized: "\(count) songs", bundle: .module)
    }

    static func sortField(_ field: TrackSort.Field) -> String {
        switch field {
        case .title: String(localized: "Title", bundle: .module)
        case .artist: String(localized: "Artist", bundle: .module)
        case .dateAdded: String(localized: "Date Added", bundle: .module)
        case .duration: String(localized: "Duration", bundle: .module)
        case .playCount: String(localized: "Play Count", bundle: .module)
        }
    }

    static func scope(_ scope: SearchScope) -> String {
        switch scope {
        case .all: String(localized: "All", bundle: .module)
        case .title: String(localized: "Title", bundle: .module)
        case .artist: String(localized: "Artist", bundle: .module)
        case .album: String(localized: "Album", bundle: .module)
        }
    }
}
