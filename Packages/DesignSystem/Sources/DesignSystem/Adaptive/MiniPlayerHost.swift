import SwiftUI

/// Geometry of the iOS 18 mini player overlay.
enum MiniPlayerMetrics {
    static let height: CGFloat = 60
    static let margin: CGFloat = 8
    /// Standard `UITabBar` heights on iPhone (regular / compact vertical size class).
    static let tabBarHeight: CGFloat = 49
    static let compactTabBarHeight: CGFloat = 32
    /// Space content must leave at the bottom so the last row isn't hidden behind the mini player.
    static var contentInset: CGFloat {
        height + margin * 2
    }
}

extension EnvironmentValues {
    // Bottom inset reserved for the iOS 18 mini player overlay. Zero on iOS 26, where the system manages it.
    @Entry var miniPlayerInset: CGFloat = 0
}

public extension View {
    /// Hosts a mini player above the tab bar of a `TabView`.
    ///
    /// - iOS 26: `.tabViewBottomAccessory`.
    /// - iOS 18: an overlay above the tab bar on `.regularMaterial`. Root views of the tabs call
    ///   `miniPlayerContentInset()` so scrollable content isn't hidden under it.
    func miniPlayerHost(isVisible: Bool = true, @ViewBuilder content: () -> some View) -> some View {
        modifier(MiniPlayerHostModifier(isVisible: isVisible, accessory: content()))
    }

    /// Reserves space at the bottom of a tab's root view for the mini player. No-op when it's hidden or on iOS 26.
    /// Apply it to the scrollable content (`List`, `ScrollView`) inside each tab.
    func miniPlayerContentInset() -> some View {
        modifier(MiniPlayerContentInsetModifier())
    }

    /// Collapses the tab bar while scrolling down on iOS 26. No-op on iOS 18.
    @ViewBuilder
    func adaptiveTabBarMinimize() -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                tabBarMinimizeBehavior(.onScrollDown)
            } else {
                self
            }
        #else
            self
        #endif
    }
}

private struct MiniPlayerHostModifier<Accessory: View>: ViewModifier {
    let isVisible: Bool
    let accessory: Accessory
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                content.tabViewBottomAccessory(isEnabled: isVisible) { accessory }
            } else {
                legacy(content)
            }
        #else
            legacy(content)
        #endif
    }

    private func legacy(_ content: Content) -> some View {
        let tabBar = verticalSizeClass == .compact ? MiniPlayerMetrics.compactTabBarHeight : MiniPlayerMetrics.tabBarHeight
        return content
            .environment(\.miniPlayerInset, isVisible ? MiniPlayerMetrics.contentInset : 0)
            .overlay(alignment: .bottom) {
                if isVisible {
                    accessory
                        .frame(height: MiniPlayerMetrics.height)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                        .padding(.horizontal, MiniPlayerMetrics.margin)
                        .padding(.bottom, tabBar + MiniPlayerMetrics.margin)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: isVisible)
    }
}

private struct MiniPlayerContentInsetModifier: ViewModifier {
    @Environment(\.miniPlayerInset) private var inset

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: inset)
        }
    }
}
