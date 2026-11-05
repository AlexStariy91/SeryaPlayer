import SwiftUI

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
