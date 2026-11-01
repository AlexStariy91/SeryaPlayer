import Domain
import Foundation

/// Which positions of long tracks are worth remembering. A track of `minimumDuration` or longer is
/// resumed where it was left, unless that was the very start or the very end: then the entry is dropped.
struct PositionMemory {
    static let minimumDuration: TimeInterval = 20 * 60
    static let nearStart: TimeInterval = 10
    static let nearEnd: TimeInterval = 30

    let repository: any TrackPositionRepository

    /// Where to start `track`: the remembered position, or 0 for short tracks and stale entries.
    func resumePosition(for track: Track) -> TimeInterval {
        guard track.duration >= Self.minimumDuration, let saved = repository.position(for: track.id) else { return 0 }
        guard isWorthResuming(saved, in: track) else {
            repository.remove(trackIDs: [track.id])
            return 0
        }
        return saved
    }

    /// Saves `position`, or clears the entry when it is near the start or the end. Short tracks are ignored.
    func record(_ position: TimeInterval, for track: Track) {
        guard track.duration >= Self.minimumDuration else { return }
        if isWorthResuming(position, in: track) {
            repository.save(position: position, for: track.id)
        } else {
            repository.remove(trackIDs: [track.id])
        }
    }

    private func isWorthResuming(_ position: TimeInterval, in track: Track) -> Bool {
        position >= Self.nearStart && position <= track.duration - Self.nearEnd
    }
}
