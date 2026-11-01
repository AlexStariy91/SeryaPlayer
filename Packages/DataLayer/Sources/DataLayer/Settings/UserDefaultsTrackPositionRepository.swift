import Domain
import Foundation
import Shared
import Synchronization

/// Remembered positions as one `[track ID: seconds]` dictionary in the App Group `UserDefaults`.
/// Only long tracks are stored (see `DefaultPlaybackService`), so the dictionary stays small.
public final class UserDefaultsTrackPositionRepository: TrackPositionRepository {
    public static let defaultKey = "trackPositions"

    // `nonisolated(unsafe)`: `UserDefaults` is documented as thread-safe but not annotated `Sendable`.
    private nonisolated(unsafe) let defaults: UserDefaults
    private let key: String
    /// Serializes read-modify-write cycles on the dictionary.
    private let lock = Mutex(())

    /// - Parameter defaults: `AppGroup.userDefaults` in the app; a throwaway suite in tests.
    public init(defaults: UserDefaults = AppGroup.userDefaults, key: String = UserDefaultsTrackPositionRepository.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func position(for trackID: Track.ID) -> TimeInterval? {
        lock.withLock { _ in stored()[trackID.uuidString] }
    }

    public func save(position: TimeInterval, for trackID: Track.ID) {
        lock.withLock { _ in
            var positions = stored()
            positions[trackID.uuidString] = position
            defaults.set(positions, forKey: key)
        }
    }

    public func remove(trackIDs: Set<Track.ID>) {
        lock.withLock { _ in
            var positions = stored()
            let before = positions.count
            for id in trackIDs {
                positions[id.uuidString] = nil
            }
            guard positions.count != before else { return }
            defaults.set(positions, forKey: key)
        }
    }

    private func stored() -> [String: TimeInterval] {
        defaults.dictionary(forKey: key) as? [String: TimeInterval] ?? [:]
    }
}
