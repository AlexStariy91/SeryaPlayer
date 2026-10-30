@testable import DataLayer
import Domain
import Foundation
import Testing

struct FolderRepositoryTests {
    let persistence: PersistenceController
    let folders: CoreDataFolderRepository
    let tracks: CoreDataTrackRepository

    init() throws {
        persistence = try PersistenceController(store: .inMemory)
        folders = CoreDataFolderRepository(persistence: persistence)
        tracks = CoreDataTrackRepository(persistence: persistence)
    }

    @Test func createUpdateAndObserve() async throws {
        let stream = folders.observeFolders()
        #expect(try await value(from: stream).isEmpty)

        var rock = Folder(name: "Rock", sortIndex: 1)
        let jazz = Folder(name: "Jazz", sortIndex: 0)
        try await folders.create(rock)
        try await folders.create(jazz)
        #expect(try await value(from: stream) { $0.count == 2 }.map(\.name) == ["Jazz", "Rock"])

        rock.name = "Classic Rock"
        rock.parentID = jazz.id
        try await folders.update(rock)
        let updated = try await folders.folders().first { $0.id == rock.id }
        #expect(updated == rock)
    }

    @Test func deleteRemovesSubfoldersButKeepsTracks() async throws {
        let parent = Folder(name: "Parent")
        let child = Folder(name: "Child", parentID: parent.id)
        let grandchild = Folder(name: "Grandchild", parentID: child.id)
        let sibling = Folder(name: "Sibling")
        for folder in [parent, child, grandchild, sibling] {
            try await folders.create(folder)
        }
        let inParent = makeTrack(title: "A", folderID: parent.id)
        let inGrandchild = makeTrack(title: "B", folderID: grandchild.id)
        try await tracks.add([inParent, inGrandchild])

        try await folders.delete(id: parent.id)

        #expect(try await folders.folders().map(\.name) == ["Sibling"])
        let remaining = try await tracks.tracks(ids: [inParent.id, inGrandchild.id])
        #expect(remaining.count == 2)
        #expect(remaining.allSatisfy { $0.folderID == nil })
    }
}

struct PlaylistRepositoryTests {
    let persistence: PersistenceController
    let playlists: CoreDataPlaylistRepository
    let tracks: CoreDataTrackRepository

    init() throws {
        persistence = try PersistenceController(store: .inMemory)
        playlists = CoreDataPlaylistRepository(persistence: persistence)
        tracks = CoreDataTrackRepository(persistence: persistence)
    }

    @Test func createRenameObserveAndDelete() async throws {
        let stream = playlists.observePlaylists()
        #expect(try await value(from: stream).isEmpty)

        var playlist = Playlist(name: "Road")
        try await playlists.create(playlist)
        #expect(try await value(from: stream) { !$0.isEmpty } == [playlist])

        playlist.name = "Road Trip"
        playlist.coverArtworkKey = "abc"
        try await playlists.update(playlist)
        #expect(try await value(from: stream) { $0.first?.name == "Road Trip" } == [playlist])

        try await playlists.delete(id: playlist.id)
        #expect(try await value(from: stream) { $0.isEmpty }.isEmpty)
    }

    @Test func repeatedTrackReorderAndRemove() async throws {
        let a = makeTrack(title: "A")
        let b = makeTrack(title: "B")
        let c = makeTrack(title: "C")
        try await tracks.add([a, b, c])
        let playlist = Playlist(name: "Mix")
        try await playlists.create(playlist)

        try await playlists.append(trackIDs: [a.id, b.id, a.id], to: playlist.id)
        try await playlists.append(trackIDs: [c.id, UUID()], to: playlist.id)
        let stream = playlists.observeEntries(of: playlist.id)
        let entries = try await value(from: stream)
        #expect(entries.map(\.trackID) == [a.id, b.id, a.id, c.id])
        #expect(entries.map(\.sortIndex) == [0, 1, 2, 3])
        #expect(Set(entries.map(\.id)).count == 4)

        // Move C to the front, like List.onMove(fromOffsets: [3], toOffset: 0).
        try await playlists.moveEntries(fromOffsets: [3], toOffset: 0, in: playlist.id)
        let moved = try await value(from: stream) { $0.first?.trackID == c.id }
        #expect(moved.map(\.trackID) == [c.id, a.id, b.id, a.id])
        #expect(moved.map(\.sortIndex) == [0, 1, 2, 3])

        // Move the first A to the end.
        try await playlists.moveEntries(fromOffsets: [1], toOffset: 4, in: playlist.id)
        let movedDown = try await value(from: stream) { $0.last?.id == moved[1].id }
        #expect(movedDown.map(\.trackID) == [c.id, b.id, a.id, a.id])

        try await playlists.removeEntries(ids: [movedDown[1].id])
        let removed = try await value(from: stream) { $0.count == 3 }
        #expect(removed.map(\.trackID) == [c.id, a.id, a.id])
        #expect(removed.map(\.sortIndex) == [0, 1, 2])

        // Deleting a track removes all its entries.
        try await tracks.delete(ids: [a.id])
        #expect(try await value(from: stream) { $0.count == 1 }.map(\.trackID) == [c.id])
    }

    @Test func moveElementsMatchesSwiftUISemantics() {
        var items = ["a", "b", "c", "d", "e"]
        items.moveElements(fromOffsets: [1, 3], toOffset: 5)
        #expect(items == ["a", "c", "e", "b", "d"])
        items.moveElements(fromOffsets: [4], toOffset: 0)
        #expect(items == ["d", "a", "c", "e", "b"])
        items.moveElements(fromOffsets: [2], toOffset: 2)
        #expect(items == ["d", "a", "c", "e", "b"])
    }
}

struct EQPresetRepositoryTests {
    @Test func saveUpdateObserveAndDelete() async throws {
        let repository = try CoreDataEQPresetRepository(persistence: PersistenceController(store: .inMemory))
        let stream = repository.observePresets()
        #expect(try await value(from: stream).isEmpty)

        var preset = EQPreset(name: "Mine", gains: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], preamp: -3)
        try await repository.save(preset)
        #expect(try await value(from: stream) { !$0.isEmpty } == [preset])

        preset.name = "Renamed"
        preset.gains[0] = -12
        try await repository.save(preset)
        #expect(try await value(from: stream) { $0.first?.name == "Renamed" } == [preset])

        try await repository.delete(id: preset.id)
        #expect(try await value(from: stream) { $0.isEmpty }.isEmpty)
    }
}

struct PersistenceControllerTests {
    @Test func dataSurvivesRecreatingTheStackOnAFileStore() async throws {
        let directory = try TemporaryDirectory()
        defer { directory.cleanUp() }
        let storeURL = directory.url.appending(path: "Nested/SeryaPlayer.sqlite")
        let track = makeTrack(title: "Persistent")
        let playlist = Playlist(name: "Saved")

        do {
            let persistence = try PersistenceController(store: .file(storeURL))
            try await CoreDataTrackRepository(persistence: persistence).add([track])
            let playlists = CoreDataPlaylistRepository(persistence: persistence)
            try await playlists.create(playlist)
            try await playlists.append(trackIDs: [track.id], to: playlist.id)
            let batch = (0 ..< 100).map { makeTrack(title: "Batch \($0)") }
            try await CoreDataTrackRepository(persistence: persistence).add(batch)
        }

        let reopened = try PersistenceController(store: .file(storeURL))
        let tracks = CoreDataTrackRepository(persistence: reopened)
        #expect(try await tracks.tracks(ids: [track.id]) == [track])
        #expect(try await tracks.search("Batch", sortedBy: TrackSort()).count == 100)
        let entries = try await value(from: CoreDataPlaylistRepository(persistence: reopened).observeEntries(of: playlist.id))
        #expect(entries.map(\.trackID) == [track.id])
    }

    @Test func inMemoryStoresAreIsolated() async throws {
        let first = try CoreDataTrackRepository(persistence: PersistenceController(store: .inMemory))
        let second = try CoreDataTrackRepository(persistence: PersistenceController(store: .inMemory))
        try await first.add([makeTrack(title: "Only here")])
        #expect(try await second.search("", sortedBy: TrackSort()).isEmpty)
    }
}
