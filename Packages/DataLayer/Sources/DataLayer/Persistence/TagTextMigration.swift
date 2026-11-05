import CoreData
import Foundation
import Shared

/// Repairs tag text already stored in the library with `TagTextRepair` (tracks imported before
/// the reader repaired it).
///
/// Tracks are edited in place, so their IDs, playlists, play counts and saved positions stay as they
/// are; artist and album groups are computed from the text and merge on their own. The run is
/// idempotent: repaired text no longer qualifies. A version in `UserDefaults` makes it run once;
/// bump `version` when the repair learns something new.
public final class TagTextMigration: Sendable {
    public static let version = 1
    public static let defaultKey = "tagTextMigrationVersion"

    private let persistence: PersistenceController
    // `nonisolated(unsafe)`: `UserDefaults` is documented as thread-safe but not annotated `Sendable`.
    private nonisolated(unsafe) let defaults: UserDefaults
    private let key: String

    /// - Parameter defaults: `AppGroup.userDefaults` in the app; a throwaway suite in tests.
    public init(persistence: PersistenceController, defaults: UserDefaults = AppGroup.userDefaults, key: String = TagTextMigration.defaultKey) {
        self.persistence = persistence
        self.defaults = defaults
        self.key = key
    }

    /// Runs the repair unless this version already ran. Returns the number of tracks changed.
    @discardableResult
    public func runIfNeeded() async throws -> Int {
        guard defaults.integer(forKey: key) < Self.version else { return 0 }
        let changed = try await run()
        defaults.set(Self.version, forKey: key)
        return changed
    }

    /// Repairs every track, regardless of the stored version. Returns the number of tracks changed.
    @discardableResult
    public func run() async throws -> Int {
        try await persistence.performWrite { context in
            let request = CDTrack.fetchRequest()
            request.fetchBatchSize = 500
            request.propertiesToFetch = ["title", "artist", "album", "albumArtist"]
            var changed = 0
            for track in try context.fetch(request) {
                var didChange = false
                func repair(_ keyPath: ReferenceWritableKeyPath<CDTrack, String>) {
                    if let fixed = TagTextRepair.repaired(track[keyPath: keyPath]) {
                        track[keyPath: keyPath] = fixed
                        didChange = true
                    }
                }
                repair(\.title)
                repair(\.artist)
                repair(\.album)
                if let fixed = track.albumArtist.flatMap(TagTextRepair.repaired) {
                    track.albumArtist = fixed
                    didChange = true
                }
                changed += didChange ? 1 : 0
            }
            return changed
        }
    }
}
