import SwiftUI

/// A toolbar item that can drop the shared glass platter iOS 26 puts behind bar items, so a passive status
/// view (a progress ring) does not look or feel like a button. The item itself stays the same when the flag
/// flips, so a button and a status can share one slot. On iOS 18 there is no platter and this is a plain item.
public struct StatusToolbarItem<Content: View>: ToolbarContent {
    private let placement: ToolbarItemPlacement
    private let hidesBackground: Bool
    private let content: Content

    public init(
        placement: ToolbarItemPlacement = .automatic,
        hidesBackground: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.placement = placement
        self.hidesBackground = hidesBackground
        self.content = content()
    }

    public var body: some ToolbarContent {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                ToolbarItem(placement: placement) { content }
                    .sharedBackgroundVisibility(hidesBackground ? .hidden : .automatic)
            } else {
                ToolbarItem(placement: placement) { content }
            }
        #else
            ToolbarItem(placement: placement) { content }
        #endif
    }
}
