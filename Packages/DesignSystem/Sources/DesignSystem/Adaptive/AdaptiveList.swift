import SwiftUI

public extension View {
    /// For plain lists with pinned section headers. iOS 26 gives a pinned header no background of its own:
    /// a hard top scroll edge puts it on the bars' backdrop instead of over the rows. No-op on iOS 18, where
    /// pinned headers have their own background.
    @ViewBuilder
    func pinnedSectionHeaders() -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                scrollEdgeEffectStyle(.hard, for: .top)
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
