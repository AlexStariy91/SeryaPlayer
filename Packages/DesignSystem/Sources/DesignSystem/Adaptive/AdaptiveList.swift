import SwiftUI

public extension View {
    /// The content of a plain list's section header that pins while scrolling.
    ///
    /// - iOS 26: a pinned header has no background of its own, so rows scrolled under it showed through its text.
    ///   The header gets the list's background, edge to edge, with the system header's insets (16 pt leading,
    ///   10 pt above and below), so its text sits where it did. A hard top scroll edge effect (the first approach)
    ///   also covered the rows, but it left the navigation bar, its glass buttons, search field and the status bar
    ///   in the old appearance when the light/dark mode changed while the tab was in the background.
    /// - iOS 18: unchanged; pinned headers have their own background.
    @ViewBuilder
    func pinnedSectionHeader() -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .padding(.vertical, 10)
                    .background(.background)
                    .listRowInsets(EdgeInsets())
            } else {
                self
            }
        #else
            self
        #endif
    }
}

/// The selection binding for a `List` that selects rows only in edit mode.
public enum EditingSelection {
    /// - iOS 18: bound only while editing. Bound outside edit mode, the list mirrors it into the collection
    ///   view's own selection (a tapped row can stay highlighted after navigating back).
    /// - iOS 26: always bound, but empty and read-only outside edit mode. A list that gains its selection binding
    ///   together with edit mode shows the selection highlight without the checkmark circles.
    @MainActor
    public static func binding<Value: Hashable>(_ selection: Binding<Set<Value>>, isEditing: Bool) -> Binding<Set<Value>>? {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                Binding(
                    get: { isEditing ? selection.wrappedValue : [] },
                    set: { newValue in
                        if isEditing {
                            selection.wrappedValue = newValue
                        }
                    }
                )
            } else {
                isEditing ? selection : nil
            }
        #else
            isEditing ? selection : nil
        #endif
    }
}
