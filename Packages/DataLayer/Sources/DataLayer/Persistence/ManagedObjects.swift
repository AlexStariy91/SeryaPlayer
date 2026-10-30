import CoreData
import Foundation

// Hand-written NSManagedObject subclasses (codegen is off). `@objc(Name)` keeps the runtime class
// name equal to `representedClassName` in the model, without the module prefix.

@objc(CDTrack)
final class CDTrack: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var artist: String
    @NSManaged var album: String
    @NSManaged var albumArtist: String?
    @NSManaged var trackNumber: NSNumber?
    @NSManaged var duration: Double
    @NSManaged var relativePath: String
    @NSManaged var originalFileName: String
    @NSManaged var fileSize: Int64
    @NSManaged var contentHash: String
    @NSManaged var artworkKey: String?
    @NSManaged var dateAdded: Date
    @NSManaged var playCount: Int64
    @NSManaged var lastPlayedAt: Date?
    @NSManaged var folder: CDFolder?
    @NSManaged var entries: Set<CDPlaylistEntry>

    static let entityName = "CDTrack"

    @nonobjc static func fetchRequest() -> NSFetchRequest<CDTrack> {
        NSFetchRequest<CDTrack>(entityName: entityName)
    }
}

@objc(CDFolder)
final class CDFolder: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var sortIndex: Int64
    @NSManaged var createdAt: Date
    @NSManaged var parent: CDFolder?
    @NSManaged var subfolders: Set<CDFolder>
    @NSManaged var tracks: Set<CDTrack>

    static let entityName = "CDFolder"

    @nonobjc static func fetchRequest() -> NSFetchRequest<CDFolder> {
        NSFetchRequest<CDFolder>(entityName: entityName)
    }
}

@objc(CDPlaylist)
final class CDPlaylist: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var coverArtworkKey: String?
    @NSManaged var entries: Set<CDPlaylistEntry>

    static let entityName = "CDPlaylist"

    @nonobjc static func fetchRequest() -> NSFetchRequest<CDPlaylist> {
        NSFetchRequest<CDPlaylist>(entityName: entityName)
    }
}

@objc(CDPlaylistEntry)
final class CDPlaylistEntry: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var sortIndex: Int64
    @NSManaged var playlist: CDPlaylist?
    @NSManaged var track: CDTrack?

    static let entityName = "CDPlaylistEntry"

    @nonobjc static func fetchRequest() -> NSFetchRequest<CDPlaylistEntry> {
        NSFetchRequest<CDPlaylistEntry>(entityName: entityName)
    }
}

@objc(CDEQPreset)
final class CDEQPreset: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    /// `[Float]` encoded as JSON.
    @NSManaged var gains: Data
    @NSManaged var preamp: Float
    @NSManaged var createdAt: Date

    static let entityName = "CDEQPreset"

    @nonobjc static func fetchRequest() -> NSFetchRequest<CDEQPreset> {
        NSFetchRequest<CDEQPreset>(entityName: entityName)
    }
}
