import DesignSystem
import Domain
import SwiftUI

/// Library home: category rows and the Recently Added / Recently Played shelves.
struct LibraryHomeView: View {
    let context: LibraryContext

    var body: some View {
        let store = context.store
        if store.hasLoaded, store.tracks.isEmpty, store.playlists.isEmpty {
            EmptyStateView(
                LocalizedStringKey(String(localized: "No Music Yet", bundle: .module)),
                systemImage: "music.note.house",
                message: LocalizedStringKey(String(localized: "Import audio files or a whole folder to get started.", bundle: .module)),
                actionTitle: LocalizedStringKey(String(localized: "Import Files", bundle: .module))
            ) {
                context.importer.present(.files)
            }
            .accessibilityIdentifier("library.empty")
        } else {
            List {
                Section {
                    category(.allTracks, String(localized: "All Tracks", bundle: .module), "music.note", id: "library.allTracks")
                    category(.artists, String(localized: "Artists", bundle: .module), "music.mic", id: "library.artists")
                    category(.albums, String(localized: "Albums", bundle: .module), "square.stack", id: "library.albums")
                    category(.playlists, String(localized: "Playlists", bundle: .module), "music.note.list", id: "library.playlists")
                }
                shelf(String(localized: "Recently Added", bundle: .module), tracks: store.recentlyAdded)
                shelf(String(localized: "Recently Played", bundle: .module), tracks: store.recentlyPlayed)
            }
            .listStyle(.plain)
        }
    }

    private func category(_ route: LibraryRoute, _ title: String, _ systemImage: String, id: String) -> some View {
        NavigationLink(value: route) {
            Label {
                Text(title).font(AppFont.sectionTitle.weight(.regular))
            } icon: {
                Image(systemName: systemImage).foregroundStyle(Color.accentColor)
            }
            .padding(.vertical, Spacing.xs)
        }
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private func shelf(_ title: String, tracks: [Track]) -> some View {
        if !tracks.isEmpty {
            Section {
                TrackShelf(tracks: tracks, context: context)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            } header: {
                Text(title)
                    .font(AppFont.sectionTitle)
                    .foregroundStyle(SemanticColor.textPrimary)
                    .textCase(nil)
            }
            .listSectionSeparator(.hidden)
        }
    }
}
