import CoreData
import Domain
import Foundation

public enum DataLayerError: Error, Equatable {
    case notFound(entity: String, id: UUID)
}

extension NSManagedObjectContext {
    func fetchOne<T: NSManagedObject>(_ request: NSFetchRequest<T>, id: UUID) throws -> T? {
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    func fetchOrThrow<T: NSManagedObject>(_ request: NSFetchRequest<T>, id: UUID, entity: String) throws -> T {
        guard let object = try fetchOne(request, id: id) else {
            throw DataLayerError.notFound(entity: entity, id: id)
        }
        return object
    }
}

// MARK: - Track

extension CDTrack {
    func toDomain() -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            trackNumber: trackNumber?.intValue,
            duration: duration,
            relativePath: relativePath,
            originalFileName: originalFileName,
            fileSize: fileSize,
            contentHash: contentHash,
            artworkKey: artworkKey,
            folderID: folder?.id,
            dateAdded: dateAdded,
            playCount: Int(playCount),
            lastPlayedAt: lastPlayedAt
        )
    }

    /// Copies every field except the folder relationship.
    func apply(_ track: Track) {
        id = track.id
        title = track.title
        artist = track.artist
        album = track.album
        albumArtist = track.albumArtist
        trackNumber = track.trackNumber.map { NSNumber(value: $0) }
        duration = track.duration
        relativePath = track.relativePath
        originalFileName = track.originalFileName
        fileSize = track.fileSize
        contentHash = track.contentHash
        artworkKey = track.artworkKey
        dateAdded = track.dateAdded
        playCount = Int64(track.playCount)
        lastPlayedAt = track.lastPlayedAt
    }

    /// Attribute dictionary for `NSBatchInsertRequest` (relationships are not supported there).
    static func batchValues(for track: Track) -> [String: Any] {
        var values: [String: Any] = [
            "id": track.id,
            "title": track.title,
            "artist": track.artist,
            "album": track.album,
            "duration": track.duration,
            "relativePath": track.relativePath,
            "originalFileName": track.originalFileName,
            "fileSize": track.fileSize,
            "contentHash": track.contentHash,
            "dateAdded": track.dateAdded,
            "playCount": Int64(track.playCount),
        ]
        values["albumArtist"] = track.albumArtist
        values["trackNumber"] = track.trackNumber.map { NSNumber(value: $0) }
        values["artworkKey"] = track.artworkKey
        values["lastPlayedAt"] = track.lastPlayedAt
        return values
    }
}

extension TrackSort {
    var sortDescriptors: [NSSortDescriptor] {
        func text(_ key: String, _ ascending: Bool = true) -> NSSortDescriptor {
            NSSortDescriptor(key: key, ascending: ascending, selector: #selector(NSString.localizedStandardCompare(_:)))
        }
        let primary: [NSSortDescriptor] = switch field {
        case .title:
            [text("title", ascending), text("artist")]
        case .artist:
            [text("artist", ascending), text("album"), NSSortDescriptor(key: "trackNumber", ascending: true), text("title")]
        case .dateAdded:
            [NSSortDescriptor(key: "dateAdded", ascending: ascending), text("title")]
        case .duration:
            [NSSortDescriptor(key: "duration", ascending: ascending), text("title")]
        case .playCount:
            [NSSortDescriptor(key: "playCount", ascending: ascending), text("title")]
        }
        // A stable tiebreaker keeps the order deterministic for equal keys.
        return primary + [NSSortDescriptor(key: "dateAdded", ascending: true)]
    }
}

// MARK: - Folder

extension CDFolder {
    func toDomain() -> Folder {
        Folder(id: id, name: name, parentID: parent?.id, sortIndex: Int(sortIndex), createdAt: createdAt)
    }

    func apply(_ folder: Folder) {
        id = folder.id
        name = folder.name
        sortIndex = Int64(folder.sortIndex)
        createdAt = folder.createdAt
    }
}

// MARK: - Playlist

extension CDPlaylist {
    func toDomain() -> Playlist {
        Playlist(id: id, name: name, createdAt: createdAt, coverArtworkKey: coverArtworkKey)
    }

    func apply(_ playlist: Playlist) {
        id = playlist.id
        name = playlist.name
        createdAt = playlist.createdAt
        coverArtworkKey = playlist.coverArtworkKey
    }
}

extension CDPlaylistEntry {
    /// `nil` only for an entry whose track is gone (deleting a track cascades to its entries).
    func toDomain() -> PlaylistEntry? {
        guard let track else { return nil }
        return PlaylistEntry(id: id, trackID: track.id, sortIndex: Int(sortIndex))
    }
}

// MARK: - EQ preset

extension CDEQPreset {
    func toDomain() -> EQPreset {
        let decoded = (try? JSONDecoder().decode([Float].self, from: gains)) ?? []
        let bands = decoded.count == EQBands.count ? decoded : Array(repeating: 0, count: EQBands.count)
        return EQPreset(id: id, name: name, gains: bands, preamp: preamp, isBuiltIn: false, createdAt: createdAt)
    }

    func apply(_ preset: EQPreset) throws {
        id = preset.id
        name = preset.name
        gains = try JSONEncoder().encode(preset.gains)
        preamp = preset.preamp
        createdAt = preset.createdAt
    }
}
