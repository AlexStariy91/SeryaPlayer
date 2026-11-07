import Domain
import DomainTestSupport
import Foundation
import Testing

struct TrackPlayStatisticsTests {
    @Test func playStatisticsAreIgnored() {
        let track = Track.fixture("Song")
        var played = track
        played.playCount += 3
        played.lastPlayedAt = Date()
        #expect(played.hasSameCatalogData(as: track))
        let other = Track.fixture("Other")
        #expect([played, other].hasSameCatalogData(as: [track, other]))
    }

    @Test func catalogChangesAreNot() {
        let track = Track.fixture("Song")
        var renamed = track
        renamed.title = "Renamed"
        var moved = track
        moved.folderID = UUID()
        #expect(!renamed.hasSameCatalogData(as: track))
        #expect(!moved.hasSameCatalogData(as: track))
        #expect(![track].hasSameCatalogData(as: []))
        #expect(![track, renamed].hasSameCatalogData(as: [renamed, track]))
        #expect([track, renamed].hasSameCatalogData(as: [track, renamed]))
    }
}
