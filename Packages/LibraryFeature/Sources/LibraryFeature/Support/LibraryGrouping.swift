import Domain
import Foundation

/// Pure grouping and shelf logic over a library snapshot. Linear in the number of tracks.
enum LibraryGrouping {
    static let shelfLimit = 20

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Artists by name (unknown last); each artist's tracks ordered by album, track number, title.
    static func artists(from tracks: [Track]) -> [TrackGroup] {
        var buckets: [String: (name: String, tracks: [Track])] = [:]
        for track in tracks {
            let name = track.artist.trimmingCharacters(in: .whitespaces)
            buckets[fold(name), default: (name, [])].tracks.append(track)
        }
        return buckets
            .map { key, value in
                TrackGroup(id: "artist:" + key, kind: .artist, name: value.name, artist: "", tracks: value.tracks.sorted(by: albumOrder))
            }
            .sorted(by: nameOrder)
    }

    /// Albums keyed by album artist (falling back to artist) and album title.
    static func albums(from tracks: [Track]) -> [TrackGroup] {
        var buckets: [String: TrackGroup] = [:]
        for track in tracks {
            let album = track.album.trimmingCharacters(in: .whitespaces)
            let artist = (track.albumArtist ?? track.artist).trimmingCharacters(in: .whitespaces)
            let id = "album:" + fold(artist) + "|" + fold(album)
            buckets[id, default: TrackGroup(id: id, kind: .album, name: album, artist: artist, tracks: [])].tracks.append(track)
        }
        return buckets.values
            .map { TrackGroup(id: $0.id, kind: .album, name: $0.name, artist: $0.artist, tracks: $0.tracks.sorted(by: albumOrder)) }
            .sorted(by: nameOrder)
    }

    static func recentlyAdded(_ tracks: [Track]) -> [Track] {
        Array(tracks.sorted { $0.dateAdded > $1.dateAdded }.prefix(shelfLimit))
    }

    static func recentlyPlayed(_ tracks: [Track]) -> [Track] {
        let played = tracks.filter { $0.lastPlayedAt != nil }
        return Array(played.sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }.prefix(shelfLimit))
    }

    private static func albumOrder(_ lhs: Track, _ rhs: Track) -> Bool {
        if lhs.album != rhs.album {
            return lhs.album.localizedStandardCompare(rhs.album) == .orderedAscending
        }
        if lhs.trackNumber != rhs.trackNumber {
            return (lhs.trackNumber ?? .max) < (rhs.trackNumber ?? .max)
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    /// Named groups first in localized order; the unknown (empty) group goes last.
    private static func nameOrder(_ lhs: TrackGroup, _ rhs: TrackGroup) -> Bool {
        switch (lhs.name.isEmpty, rhs.name.isEmpty) {
        case (true, false): false
        case (false, true): true
        default:
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                || (lhs.name == rhs.name && lhs.artist.localizedStandardCompare(rhs.artist) == .orderedAscending)
        }
    }
}
