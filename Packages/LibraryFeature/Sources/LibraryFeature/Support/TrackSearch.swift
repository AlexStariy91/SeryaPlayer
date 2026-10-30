import Domain
import Foundation

/// What a search query is matched against.
enum SearchScope: String, CaseIterable, Hashable, Sendable {
    case all, title, artist, album
}

/// Case-, diacritic- and width-insensitive search over pre-folded keys.
/// Folding is done once per library snapshot, so each keystroke is a plain substring scan.
struct TrackSearchIndex: Sendable {
    private struct Entry {
        let title: String
        let artist: String
        let album: String
    }

    private let entries: [Entry]

    init(_ tracks: [Track]) {
        entries = tracks.map {
            Entry(title: LibraryGrouping.fold($0.title), artist: LibraryGrouping.fold($0.artist), album: LibraryGrouping.fold($0.album))
        }
    }

    /// Indices of matching tracks, in the original order. A blank query matches nothing.
    func matches(_ query: String, scope: SearchScope) -> [Int] {
        let needle = LibraryGrouping.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return [] }
        return entries.indices.filter { index in
            let entry = entries[index]
            switch scope {
            case .all: return Self.contains(entry.title, needle) || Self.contains(entry.artist, needle) || Self.contains(entry.album, needle)
            case .title: return Self.contains(entry.title, needle)
            case .artist: return Self.contains(entry.artist, needle)
            case .album: return Self.contains(entry.album, needle)
            }
        }
    }

    /// Both sides are already folded, so a literal (code unit) search is enough and much faster
    /// than `String.contains`, which does full Unicode comparison.
    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(of: needle, options: .literal) != nil
    }

    static func filter(_ tracks: [Track], query: String, scope: SearchScope) -> [Track] {
        TrackSearchIndex(tracks).matches(query, scope: scope).map { tracks[$0] }
    }
}
