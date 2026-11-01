import DesignSystem
import Domain
import SwiftUI

/// Library home: category rows and the Recently Added / Recently Played shelves.
///
/// A `ScrollView`, not a `List`: a List cell owns one context-menu interaction for the whole row, so a
/// long press anywhere on a shelf lifted the row and showed the first card's menu instead of the pressed card's.
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    CategoryDivider()
                    category(.allTracks, String(localized: "All Tracks", bundle: .module), "music.note", id: "library.allTracks")
                    category(.artists, String(localized: "Artists", bundle: .module), "music.mic", id: "library.artists")
                    category(.albums, String(localized: "Albums", bundle: .module), "square.stack", id: "library.albums")
                    category(.playlists, String(localized: "Playlists", bundle: .module), "music.note.list", id: "library.playlists")
                    shelf(String(localized: "Recently Added", bundle: .module), tracks: store.recentlyAdded)
                    shelf(String(localized: "Recently Played", bundle: .module), tracks: store.recentlyPlayed)
                }
                .padding(.bottom, Spacing.xl)
            }
            // Batched imports add tracks a chunk at a time: ease the shelves instead of snapping.
            .animation(.default, value: store.recentlyAdded.map(\.id))
        }
    }

    private func category(_ route: LibraryRoute, _ title: String, _ systemImage: String, id: String) -> some View {
        VStack(spacing: 0) {
            NavigationLink(value: route) {
                HStack(spacing: Spacing.m) {
                    Image(systemName: systemImage)
                        .font(AppFont.sectionTitle.weight(.regular))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: CategoryDivider.iconWidth)
                    Text(title)
                        .font(AppFont.sectionTitle.weight(.regular))
                        .foregroundStyle(SemanticColor.textPrimary)
                    Spacer(minLength: Spacing.s)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SemanticColor.textTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, Spacing.m)
                .padding(.leading, Spacing.screenMargin)
                .padding(.trailing, Spacing.screenMargin + Spacing.xs)
                .frame(minHeight: 52)
                .contentShape(.rect)
            }
            .buttonStyle(CategoryRowStyle())
            .accessibilityIdentifier(id)
            CategoryDivider()
        }
    }

    @ViewBuilder
    private func shelf(_ title: String, tracks: [Track]) -> some View {
        if !tracks.isEmpty {
            Text(title)
                .font(AppFont.sectionTitle)
                .foregroundStyle(SemanticColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, Spacing.screenMargin + Spacing.xs)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.s)
            TrackShelf(tracks: tracks, context: context)
        }
    }
}

/// A row separator inset to the category titles, like a plain `List`'s.
private struct CategoryDivider: View {
    static let iconWidth: CGFloat = 36
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(SemanticColor.separator)
            .frame(height: 1 / displayScale)
            .padding(.leading, Spacing.screenMargin + Self.iconWidth + Spacing.m)
    }
}

/// The List-like pressed highlight for the category rows.
private struct CategoryRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(uiColor: .systemFill) : .clear)
    }
}
