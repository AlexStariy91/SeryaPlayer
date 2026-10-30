import DesignSystem
import Domain
import SwiftUI

/// "Add to Playlist…": pick an existing playlist or create one with the tracks.
struct PlaylistPickerView: View {
    let tracks: [Track]
    let store: LibraryStore
    let actions: TrackActionsModel

    @Environment(\.dismiss) private var dismiss
    @State private var isNaming = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Button(String(localized: "New Playlist…", bundle: .module), systemImage: "plus") {
                    isNaming = true
                }
                ForEach(store.playlists) { playlist in
                    Button {
                        Task {
                            await actions.add(tracks, to: playlist)
                            dismiss()
                        }
                    } label: {
                        Label(playlist.name, systemImage: "music.note.list")
                            .foregroundStyle(SemanticColor.textPrimary)
                    }
                }
            }
            .navigationTitle(Text("Add to Playlist", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { dismiss() }
                }
            }
            .alert(String(localized: "New Playlist", bundle: .module), isPresented: $isNaming) {
                TextField(String(localized: "Name", bundle: .module), text: $newName)
                Button(String(localized: "Cancel", bundle: .module), role: .cancel) { newName = "" }
                Button(String(localized: "Create", bundle: .module)) {
                    let name = newName
                    newName = ""
                    Task {
                        await actions.addToNewPlaylist(named: name, tracks: tracks)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
