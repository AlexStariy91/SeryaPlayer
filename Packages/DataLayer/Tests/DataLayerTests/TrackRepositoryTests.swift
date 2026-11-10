@testable import DataLayer
import Domain
import Foundation
import Synchronization
import Testing

struct TrackRepositoryTests {
    let persistence: PersistenceController
    let repository: CoreDataTrackRepository

    init() throws {
        persistence = try PersistenceController(store: .inMemory)
        // Every change is published at once; the coalescing tests below make their own repository.
        repository = CoreDataTrackRepository(persistence: persistence, observationInterval: .zero)
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
        let stream = repository.observeTracks(sortedBy: TrackSort(field: .dateAdded))
        #expect(try await value(from: stream).isEmpty)

        let start = Date.now
        let tracks = (0 ..< 1000).map { index in
            makeTrack(title: "Track \(index)", dateAdded: start.addingTimeInterval(Double(index)))
        }
        // Runs off the main actor; the main actor stays free while the batch is written.
        try await Task.detached { [repository] in
            try await repository.add(tracks)
        }.value

        let observed = try await value(from: stream) { $0.count == 1000 }
        #expect(observed.first?.title == "Track 0")

        // The view context sees the batch too.
        let viewCount = try await MainActor.run {
            try persistence.viewContext.count(for: CDTrack.fetchRequest())
        }
        #expect(viewCount == 1000)
    }

    @Test func observationEmitsOnDeleteOfManyTracksInAFolder() async throws {
        let folders = CoreDataFolderRepository(persistence: persistence)
        let folder = Folder(name: "Imported")
        try await folders.create(folder)
        let stream = repository.observeTracks(sortedBy: TrackSort(field: .dateAdded))
        #expect(try await value(from: stream).isEmpty)

        let tracks = (0 ..< 120).map { makeTrack(title: "Track \($0)", folderID: folder.id) }
        try await repository.add(tracks)
        let added = try await value(from: stream) { $0.count == 120 }
        #expect(added.allSatisfy { $0.folderID == folder.id })

        try await repository.delete(ids: tracks.prefix(20).map(\.id))
        let afterDelete = try await value(from: stream) { $0.count == 100 }
        #expect(afterDelete.allSatisfy { $0.folderID == folder.id })
    }

    /// An import writes in chunks and every track start writes a play record; observers must get those bursts
    /// coalesced, yet always end with the latest state.
    @Test func burstsOfWritesReachObserversCoalesced() async throws {
        // Longer than in the app, so a slow machine that spreads the writes out still coalesces them.
        let repository = CoreDataTrackRepository(persistence: persistence, observationInterval: .seconds(1))
        let stream = repository.observeTracks(sortedBy: TrackSort())
        let received = Task {
            var lists: [[Track]] = []
            for await list in stream {
                lists.append(list)
                if list.count == 30, list.allSatisfy({ $0.playCount == 1 }) {
                    break
                }
            }
            return lists
        }
        let timeout = Task {
            try await Task.sleep(for: .seconds(20))
            received.cancel()
        }
        defer { timeout.cancel() }
        // Spaced out, so a reader that keeps up would see every write if nothing coalesced them.
        let tracks = (0 ..< 30).map { makeTrack(title: "Track \($0)") }
        for track in tracks {
            try await repository.add([track])
            try await Task.sleep(for: .milliseconds(15))
        }
        for track in tracks {
            try await repository.markPlayed(id: track.id, at: .now)
            try await Task.sleep(for: .milliseconds(15))
        }
        let lists = await received.value
        #expect(lists.last?.count == 30)
        #expect(lists.count < 15, "published \(lists.count) lists for 60 writes")
    }

    /// The Folders root lists tracks with no folder as loose songs, so tracks imported into a folder must never be
    /// seen without it: not by an observer, and not by a reader that starts while they are being written.
    @Test func manyTracksAddedIntoAFolderAreNeverSeenWithoutIt() async throws {
        let folders = CoreDataFolderRepository(persistence: persistence)
        let folder = Folder(name: "Importing")
        try await folders.create(folder)
        let stream = repository.observeTracks(sortedBy: TrackSort())
        #expect(try await value(from: stream).isEmpty)
        let received = Task {
            var lists: [[Track]] = []
            for await list in stream {
                lists.append(list)
                if list.count == 120 {
                    break
                }
            }
            return lists
        }
        let timeout = Task {
            try await Task.sleep(for: .seconds(20))
            received.cancel()
        }
        defer { timeout.cancel() }
        // Reads the library root over and over while the tracks are written, like a screen opening mid-import.
        let isWriting = Flag(true)
        let rootReader = Task { [repository] in
            var looseCounts: [Int] = []
            while isWriting.value {
                try await looseCounts.append(repository.tracks(inFolder: nil, includeSubfolders: false).count)
            }
            return looseCounts
        }

        let tracks = (0 ..< 120).map { makeTrack(title: "Track \($0)", folderID: folder.id) }
        #expect(tracks.count >= CoreDataTrackRepository.batchInsertThreshold)
        try await repository.add(tracks)
        isWriting.value = false

        let lists = await received.value
        #expect(lists.last?.count == 120)
        let loose = lists.map { $0.count { $0.folderID == nil } }
        #expect(loose.allSatisfy { $0 == 0 }, "tracks without a folder per published list: \(loose)")
        let rootReads = try await rootReader.value
        #expect(rootReads.allSatisfy { $0 == 0 }, "root reads during the write: \(rootReads)")
    }

    @Test func aSingleWriteAfterAQuietPeriodIsPublishedAtOnce() async throws {
        // Long enough that "at once" can't be confused with the trailing publish, even on a slow machine.
        let interval = Duration.seconds(2)
        let repository = CoreDataTrackRepository(persistence: persistence, observationInterval: interval)
        let stream = repository.observeTracks(sortedBy: TrackSort())
        #expect(try await value(from: stream).isEmpty)
        try await Task.sleep(for: interval)
        let clock = ContinuousClock()
        let started = clock.now
        try await repository.add([makeTrack(title: "Now")])
        _ = try await value(from: stream) { $0.count == 1 }
        // A wall-clock limit: skipped on CI, where `scripts/test.sh` forwards `CI` as `TEST_RUNNER_CI`.
        if ProcessInfo.processInfo.environment["CI"]?.isEmpty ?? true {
            #expect(clock.now - started < interval)
        }
    }
}

/// A Bool shared between a test and the task it starts.
private final class Flag: Sendable {
    private let storage: Mutex<Bool>

    init(_ value: Bool) {
        storage = Mutex(value)
    }

    var value: Bool {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}
