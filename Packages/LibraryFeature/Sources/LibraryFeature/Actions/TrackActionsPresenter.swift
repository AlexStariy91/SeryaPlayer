import Domain
import SwiftUI

/// Presents the sheets, delete confirmation and errors requested through `TrackActionsModel`.
struct TrackActionsPresenter: ViewModifier {
    let context: LibraryContext

    func body(content: Content) -> some View {
        @Bindable var actions = context.actions
        content
            .sheet(item: $actions.sheet) { sheet in
                switch sheet {
                case let .addToPlaylist(tracks):
                    PlaylistPickerView(tracks: tracks, store: context.store, actions: actions)
                case let .moveToFolder(tracks):
                    FolderPickerView(tracks: tracks, folders: context.folders, actions: actions)
                case let .editTags(track):
                    TagEditorView(viewModel: TagEditorViewModel(track: track, editTags: actions.editTags), artwork: context.artwork)
                }
            }
            .confirmationDialog(
                deletionTitle,
                isPresented: $actions.isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete", bundle: .module), role: .destructive) {
                    Task { await actions.confirmDeletion() }
                }
            } message: {
                Text("The audio files will be removed from this device.", bundle: .module)
            }
            .alert(
                String(localized: "Something Went Wrong", bundle: .module),
                isPresented: $actions.isShowingError,
                presenting: actions.errorMessage
            ) { _ in
                Button(String(localized: "OK", bundle: .module), role: .cancel) {}
            } message: { message in
                Text(message)
            }
    }

    private var deletionTitle: String {
        let tracks = context.actions.pendingDeletion
        if tracks.count == 1, let track = tracks.first {
            return String(localized: "Delete “\(track.title)”?", bundle: .module)
        }
        return String(localized: "Delete \(tracks.count) songs?", bundle: .module)
    }
}

extension View {
    func trackActionsPresenter(_ context: LibraryContext) -> some View {
        modifier(TrackActionsPresenter(context: context))
    }
}
