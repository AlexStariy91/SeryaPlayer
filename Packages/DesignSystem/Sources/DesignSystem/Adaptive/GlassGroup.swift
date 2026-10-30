import SwiftUI

/// Groups neighboring glass elements so they blend and morph together (`GlassEffectContainer` on iOS 26).
/// On iOS 18 it is a plain container.
public struct GlassGroup<Content: View>: View {
    private let spacing: CGFloat?
    private let content: Content

    public init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: spacing) { content }
            } else {
                content
            }
        #else
            content
        #endif
    }
}
