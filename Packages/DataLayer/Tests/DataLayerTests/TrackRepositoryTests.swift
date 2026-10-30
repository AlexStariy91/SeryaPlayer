@testable import DataLayer
import Domain
import Foundation
import Testing

struct TrackRepositoryTests {
    let persistence: PersistenceController
    let repository: CoreDataTrackRepository

    init() throws {
        persistence = try PersistenceController(store: .inMemory)
        repository = CoreDataTrackRepository(persistence: persistence)
    }

    @Test func addAndFetchByIDsPreservesRequestedOrder() async throws {
        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")
        try await repository.add([first, second])

        let fetched = try await repository.tracks(ids: [second.id, UUID(), first.id])
        #expect(fetched == [second, first])
    }

    @Test func searchIgnoresCaseAndDiacritics() async throws {
        try await repository.add([
            makeTrack(title: "Halo", artist: "Beyoncé"),
            makeTrack(title: "Ёлка", artist: "Someone"),
            makeTrack(title: "Other", artist: "Nobody", album: "Café Del Mar"),
        ])

        #expect(try await repository.search("BEYONCE", sortedBy: TrackSort()).map(\.title) == ["Halo"])
        #expect(try await repository.search("cafe", sortedBy: TrackSort()).map(\.title) == ["Other"])
        #expect(try await repository.search("елка", sortedBy: TrackSort()).map(\.title) == ["Ёлка"])
        #expect(try await repository.search("  ", sortedBy: TrackSort()).count == 3)
    }

    @Test func sortsByRequestedField() async throws {
        let now = Date.now
        try await repository.add([
            makeTrack(title: "b", artist: "Z", dateAdded: now),
            makeTrack(title: "A", artist: "Y", dateAdded: now.addingTimeInterval(-10)),
            makeTrack(title: "c", artist: "X", dateAdded: now.addingTimeInterval(10)),
        ])

        #expect(try await repository.search("", sortedBy: TrackSort(field: .title)).map(\.title) == ["A", "b", "c"])
        #expect(try await repository.search("", sortedBy: TrackSort(field: .artist)).map(\.artist) == ["X", "Y", "Z"])
        #expect(try await repository.search("", sortedBy: TrackSort(field: .dateAdded, ascending: false)).map(\.title) == ["c", "b", "A"])
    }

    @Test func findsTrackByContentHash() async throws {
        let track = makeTrack(title: "Song", hash: "42-abc")
        try await repository.add([track])

        #expect(try await repository.track(withContentHash: "42-abc") == track)
        #expect(try await repository.track(withContentHash: "missing") == nil)
    }

    @Test func updateMarkPlayedAndDelete() async throws {
        var track = makeTrack(title: "Old")
        try await repository.add([track])

        track.title = "New"
        track.trackNumber = 7
        try await repository.update(track)
        let playedAt = Date(timeIntervalSince1970: 1_000_000)
        try await repository.markPlayed(id: track.id, at: playedAt)

        let updated = try #require(try await repository.tracks(ids: [track.id]).first)
        #expect(updated.title == "New")
        #expect(updated.trackNumber == 7)
        #expect(updated.playCount == 1)
        #expect(updated.lastPlayedAt == playedAt)

        try await repository.delete(ids: [track.id])
        #expect(try await repository.tracks(ids: [track.id]).isEmpty)
    }

    @Test func updateOfMissingTrackThrows() async throws {
        let track = makeTrack(title: "Ghost")
        await #expect(throws: DataLayerError.notFound(entity: "CDTrack", id: track.id)) {
            try await repository.update(track)
        }
    }

    @Test func tracksInFolderWithAndWithoutSubfolders() async throws {
        let folders = CoreDataFolderRepository(persistence: persistence)
        let parent = Folder(name: "Parent")
        let child = Folder(name: "Child", parentID: parent.id)
        try await folders.create(parent)
        try await folders.create(child)

        let root = makeTrack(title: "Root")
        let inParent = makeTrack(title: "InParent", folderID: parent.id)
        let inChild = makeTrack(title: "InChild", folderID: child.id)
        try await repository.add([root, inParent, inChild])

        #expect(try await repository.tracks(inFolder: nil, includeSubfolders: false).map(\.title) == ["Root"])
        #expect(try await repository.tracks(inFolder: nil, includeSubfolders: true).count == 3)
        #expect(try await repository.tracks(inFolder: parent.id, includeSubfolders: false).map(\.title) == ["InParent"])
        #expect(try await Set(repository.tracks(inFolder: parent.id, includeSubfolders: true).map(\.title)) == ["InParent", "InChild"])

        try await repository.move(trackIDs: [root.id], toFolder: child.id)
        #expect(try await repository.tracks(ids: [root.id]).first?.folderID == child.id)
        try await repository.move(trackIDs: [root.id], toFolder: nil)
        #expect(try await repository.tracks(ids: [root.id]).first?.folderID == nil)
    }

    @Test func observationStartsWithCurrentStateAndFollowsChanges() async throws {
        try await repository.add([makeTrack(title: "Existing")])
        let stream = repository.observeTracks(sortedBy: TrackSort())

        let initial = try await value(from: stream)
        #expect(initial.map(\.title) == ["Existing"])

        try await repository.add([makeTrack(title: "Added")])
        let changed = try await value(from: stream) { $0.count == 2 }
        #expect(changed.map(\.title) == ["Added", "Existing"])
    }

    @Test func eachSubscriberGetsItsOwnStream() async throws {
        try await repository.add([makeTrack(title: "One")])
        let first = try await value(from: repository.observeTracks(sortedBy: TrackSort()))
        let second = try await value(from: repository.observeTracks(sortedBy: TrackSort()))
        #expect(first == second)
    }

    @Test func batchInsertOfThousandTracksRunsInBackgroundAndReachesObservers() async throws {
        let folders = CoreDataFolderRepository(persistence: persistence)
        let folder = Folder(name: "Batch")
        try await folders.create(folder)
        let stream = repository.observeTracks(sortedBy: TrackSort(field: .dateAdded))
        #expect(try await value(from: stream).isEmpty)

        let start = Date.now
        let tracks = (0 ..< 1000).map { index in
            makeTrack(title: "Track \(index)", folderID: index.isMultiple(of: 10) ? folder.id : nil, dateAdded: start.addingTimeInterval(Double(index)))
        }
        // Runs off the main actor; the main actor stays free while the batch is written.
        try await Task.detached { [repository] in
            try await repository.add(tracks)
        }.value

        let observed = try await value(from: stream) { $0.count == 1000 }
        #expect(observed.first?.title == "Track 0")
        #expect(try await repository.tracks(inFolder: folder.id, includeSubfolders: false).count == 100)

        // The view context sees the batch too.
        let viewCount = try await MainActor.run {
            try persistence.viewContext.count(for: CDTrack.fetchRequest())
        }
        #expect(viewCount == 1000)
    }
}
