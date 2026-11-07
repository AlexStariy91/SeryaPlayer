import Foundation

/// Play statistics (`playCount`, `lastPlayedAt`) change on every track start. Observers of the whole library use
/// these helpers to tell such a change from a real catalog change, so a play record doesn't rebuild every list.
public extension Track {
    /// Equal in everything except `playCount` and `lastPlayedAt`.
    func hasSameCatalogData(as other: Track) -> Bool {
        var lhs = self
        var rhs = other
        lhs.playCount = 0
        lhs.lastPlayedAt = nil
        rhs.playCount = 0
        rhs.lastPlayedAt = nil
        return lhs == rhs
    }
}

public extension [Track] {
    /// Same tracks in the same order, ignoring play statistics. Linear; run it off the main actor for big lists.
    func hasSameCatalogData(as other: [Track]) -> Bool {
        guard count == other.count else { return false }
        return zip(self, other).allSatisfy { $0.hasSameCatalogData(as: $1) }
    }
}
