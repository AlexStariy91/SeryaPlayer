import SwiftUI

public extension View {
    /// The list style for a list of titled sections.
    ///
    /// - iOS 26: `.grouped`, whose section headers scroll with the content. A plain list pins its headers with no
    ///   background, so scrolled rows showed through them. The two remedies tried didn't hold up: a hard top scroll
    ///   edge effect left a background tab's navigation bar and status bar in the old appearance after a light/dark
    ///   change, and a header background left rows visible between the bar and the pinned header.
    ///   The grouped grey backdrop is replaced with the row colour (rows themselves are left stock, so Select mode
    ///   keeps its highlight), which removes the grey strips between sections.
    /// - iOS 18: `.plain`, with pinned headers that have their own background.
    @ViewBuilder
    func sectionedListStyle() -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                listStyle(.grouped)
                    .scrollContentBackground(.hidden)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
            } else {
                listStyle(.plain)
            }
        #else
            listStyle(.plain)
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
