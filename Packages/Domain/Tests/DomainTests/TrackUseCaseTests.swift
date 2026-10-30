import Domain
import DomainTestSupport
import Foundation
import Testing

struct TrackUseCaseTests {
    @Test func deleteRemovesRecordsAndFiles() async throws {
        let keep = Track.fixture("Keep")
        let doomed = Track.fixture("Doomed")
        let repo = InMemoryTrackRepository(tracks: [keep, doomed])
        let files = FakeFileStore()
        try await DeleteTracksUseCase(tracks: repo, files: files)([doomed])
        #expect(repo.snapshot.map(\.id) == [keep.id])
        #expect(files.deletedPaths == [doomed.relativePath])
    }

    @Test func editTagsTrimsAndStoresArtwork() async throws {
        let track = Track.fixture("Old")
        let repo = InMemoryTrackRepository(tracks: [track])
        let artwork = FakeArtworkStore()
        let edit = EditTrackTagsUseCase(tracks: repo, artwork: artwork)
        let changes = EditTrackTagsUseCase.Changes(title: " New ", artist: " Band ", album: "LP", artworkData: Data([1, 2, 3]))
        let updated = try await edit(track, changes: changes)
        #expect(updated.title == "New")
        #expect(updated.artist == "Band")
        #expect(updated.artworkKey == "art-3")
        #expect(repo.snapshot.first == updated)
        #expect(updated.relativePath == track.relativePath)
    }

    @Test func editTagsRejectsBlankTitle() async throws {
        let track = Track.fixture("Old")
        let edit = EditTrackTagsUseCase(tracks: InMemoryTrackRepository(tracks: [track]), artwork: FakeArtworkStore())
        await #expect(throws: DomainError.emptyName) {
            try await edit(track, changes: .init(title: "  ", artist: "", album: ""))
        }
    }

    @Test func moveSetsFolder() async throws {
        let track = Track.fixture("A")
        let folder = Folder(name: "Rock")
        let repo = InMemoryTrackRepository(tracks: [track])
        try await MoveTracksUseCase(tracks: repo)([track.id], toFolder: folder.id)
        #expect(repo.snapshot.first?.folderID == folder.id)
    }
}
