import SwiftUI

public extension View {
    /// Animates changes of a `Menu` and its label when `value` changes.
    ///
    /// - iOS 18: `animation(_:value:)`, as for any view.
    /// - iOS 26: no animation. The menu's label lives in a UIKit-hosted button that animates its own frame: when the
    ///   label changed width (the sleep timer's icon becoming a countdown) the new content was laid out in the old
    ///   frame and slid to the centre afterwards. Without our animation the content appears in place.
    @ViewBuilder
    func menuLabelAnimation(_ animation: Animation?, value: some Equatable) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                self
            } else {
                self.animation(animation, value: value)
            }
        #else
            self.animation(animation, value: value)
        #endif
    }
}
