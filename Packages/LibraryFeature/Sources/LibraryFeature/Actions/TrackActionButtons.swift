import Domain
import SwiftUI

/// Menu items for a track: used in context menus and in the playlist detail menu.
struct TrackActionButtons: View {
    let track: Track
    let actions: TrackActionsModel

    var body: some View {
        Section {
            Button(String(localized: "Play Next", bundle: .module), systemImage: "text.line.first.and.arrowtriangle.forward") {
                actions.playNext([track])
            }
            Button(String(localized: "Play Last", bundle: .module), systemImage: "text.line.last.and.arrowtriangle.forward") {
                actions.playLast([track])
            }
        }
        Section {
            Button(String(localized: "Add to Playlist…", bundle: .module), systemImage: "text.badge.plus") {
                actions.requestAddToPlaylist([track])
            }
            Button(String(localized: "Move to Folder…", bundle: .module), systemImage: "folder") {
                actions.requestMoveToFolder([track])
            }
            Button(String(localized: "Edit Tags…", bundle: .module), systemImage: "pencil") {
                actions.requestEditTags(track)
            }
        }
        Section {
            Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) {
                actions.requestDelete([track])
            }
        }
    }
}

extension View {
    /// Context menu plus swipe actions: leading Play Next / Play Last; trailing Delete, or
    /// Remove (from a playlist) when `onRemove` is given.
    func trackActions(for track: Track, actions: TrackActionsModel, onRemove: (() -> Void)? = nil) -> some View {
        contextMenu {
            TrackActionButtons(track: track, actions: actions)
        }
        .swipeActions(edge: .leading) {
            Button(String(localized: "Play Next", bundle: .module), systemImage: "text.line.first.and.arrowtriangle.forward") {
                actions.playNext([track])
            }
            .tint(.indigo)
            Button(String(localized: "Play Last", bundle: .module), systemImage: "text.line.last.and.arrowtriangle.forward") {
                actions.playLast([track])
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing) {
            if let onRemove {
                Button(String(localized: "Remove", bundle: .module), systemImage: "minus.circle", role: .destructive, action: onRemove)
            } else {
                // No destructive role: the row must stay until the deletion is confirmed.
                Button(String(localized: "Delete", bundle: .module), systemImage: "trash") {
                    actions.requestDelete([track])
                }
                .tint(.red)
            }
            Button(String(localized: "Add to Playlist…", bundle: .module), systemImage: "text.badge.plus") {
                actions.requestAddToPlaylist([track])
            }
            .tint(.accentColor)
        }
    }
}
