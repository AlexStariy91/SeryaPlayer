import Domain
import DomainTestSupport
import Foundation
@testable import LibraryFeature
import Testing

@MainActor
struct TrackActionsTests {
    @Test func playNextAndPlayLastGoToTheQueue() {
        let track = Track.make("A")
        let deps = TestDependencies(tracks: [track])
        let actions = deps.makeContext().actions
        actions.playNext([track])
        actions.playLast([track])
        #expect(deps.spy.playedNext == [[track]])
        #expect(deps.spy.queued == [[track]])
    }

    @Test func deleteNeedsConfirmationAndRemovesFiles() async {
        let keep = Track.make("Keep")
        let doomed = Track.make("Doomed")
        let deps = TestDependencies(tracks: [keep, doomed])
        let actions = deps.makeContext().actions

        actions.requestDelete([doomed])
        #expect(actions.isConfirmingDeletion)
        #expect(deps.tracks.snapshot.count == 2)

        await actions.confirmDeletion()
        #expect(deps.tracks.snapshot.map(\.title) == ["Keep"])
        #expect(deps.files.deletedPaths == [doomed.relativePath])
        #expect(actions.pendingDeletion.isEmpty)
    }

    @Test func addToExistingAndNewPlaylist() async throws {
        let track = Track.make("A")
        let deps = TestDependencies(tracks: [track])
        let actions = deps.makeContext().actions
        let playlist = Playlist(name: "Mix")
        try await deps.playlists.create(playlist)

        actions.requestAddToPlaylist([track])
        guard case .addToPlaylist = actions.sheet else {
            Issue.record("expected the playlist picker")
            return
        }
        await actions.add([track], to: playlist)
        #expect(deps.playlists.entries(of: playlist.id).map(\.trackID) == [track.id])

        await actions.addToNewPlaylist(named: "Fresh", tracks: [track])
        let fresh = try #require(deps.playlists.playlists.first { $0.name == "Fresh" })
        #expect(deps.playlists.entries(of: fresh.id).count == 1)
    }

    @Test func moveToFolderAndBackToRoot() async {
        let folder = Folder(name: "Rock")
        let track = Track.make("A")
        let deps = TestDependencies(tracks: [track], folders: [folder])
        let actions = deps.makeContext().actions
        await actions.move([track], toFolder: folder.id)
        #expect(deps.tracks.snapshot.first?.folderID == folder.id)
        await actions.move([track], toFolder: nil)
        #expect(deps.tracks.snapshot.first?.folderID == nil)
    }

    @Test func folderTreeIsFlattenedInOrder() {
        let rock = Folder(name: "Rock", sortIndex: 1)
        let jazz = Folder(name: "Jazz", sortIndex: 0)
        let punk = Folder(name: "Punk", parentID: rock.id)
        let rows = FolderTreeRow.flatten([punk, rock, jazz])
        #expect(rows.map(\.folder.name) == ["Jazz", "Rock", "Punk"])
        #expect(rows.map(\.depth) == [0, 0, 1])
    }

    @Test func tagEditorSavesToTheDatabaseOnly() async {
        let track = Track.make("Old", artist: "Someone")
        let deps = TestDependencies(tracks: [track])
        let actions = deps.makeContext().actions
        let editor = TagEditorViewModel(track: track, editTags: actions.editTags)
        #expect(!editor.hasChanges)

        editor.title = "New"
        editor.setArtwork(Data([1, 2, 3, 4]))
        #expect(await editor.save())
        let saved = deps.tracks.snapshot.first
        #expect(saved?.title == "New")
        #expect(saved?.artist == "Someone")
        #expect(saved?.artworkKey == "art-4")
        #expect(saved?.relativePath == track.relativePath)

        editor.title = " "
        #expect(!editor.canSave)
        #expect(await editor.save() == false)
        #expect(editor.errorMessage == "The title can't be empty.")
    }
}
