import Domain
import Foundation

/// An artist or an album: a named, ordered set of tracks. Built by `LibraryGrouping`.
struct TrackGroup: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case artist
        case album
    }

    /// `artist:<folded name>` or `album:<folded artist>|<folded album>`; stable across snapshots.
    let id: String
    let kind: Kind
    /// Raw name; empty means "Unknown Artist" / "Unknown Album".
    let name: String
    /// The album's artist; empty for artist groups.
    let artist: String
    var tracks: [Track]

    var artworkKey: String? {
        tracks.lazy.compactMap(\.artworkKey).first
    }

    var albumCount: Int {
        Set(tracks.map { LibraryGrouping.fold($0.album) }).count
    }
}
