import Domain
import Foundation
import Observation

/// Edits title, artist, album and artwork in the database. The audio file is never touched.
@MainActor
@Observable
final class TagEditorViewModel {
    var title: String
    var artist: String
    var album: String
    /// Newly picked artwork, not yet saved.
    private(set) var artworkData: Data?
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    let track: Track
    @ObservationIgnored private let editTags: EditTrackTagsUseCase

    init(track: Track, editTags: EditTrackTagsUseCase) {
        self.track = track
        self.editTags = editTags
        title = track.title
        artist = track.artist
        album = track.album
    }

    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var hasChanges: Bool {
        title != track.title || artist != track.artist || album != track.album || artworkData != nil
    }

    func setArtwork(_ data: Data?) {
        artworkData = data
    }

    /// Returns true when saved, so the view can dismiss.
    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await editTags(track, changes: .init(title: title, artist: artist, album: album, artworkData: artworkData))
            errorMessage = nil
            return true
        } catch DomainError.emptyName {
            errorMessage = String(localized: "The title can't be empty.", bundle: .module)
        } catch {
            errorMessage = error.localizedDescription
        }
        return false
    }
}
