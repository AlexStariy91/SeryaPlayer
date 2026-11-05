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
    /// Apply it to a tab's root view; it adds a bottom content margin to every scroll view inside.
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
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26.1, *) {
                content.tabViewBottomAccessory(isEnabled: isVisible) { glassAccessory }
            } else if #available(iOS 26, *) {
                // iOS 26.0 has no `isEnabled:`, and attaching the accessory conditionally would rebuild the
                // whole `TabView`. Keep the bar attached and leave it empty while nothing is queued.
                content.tabViewBottomAccessory {
                    if isVisible {
                        glassAccessory
                    }
                }
            } else {
                legacy(content)
            }
        #else
            legacy(content)
        #endif
    }

    /// The accessory content in the app's color scheme. Over mixed content (a dark cover under part of the bar)
    /// iOS 26 gives the accessory a dark scheme while its glass stays light, so labels came out white on light
    /// glass; the tab bar right below keeps the app's scheme. A known iOS 26 issue (FB21365706).
    private var glassAccessory: some View {
        accessory.environment(\.colorScheme, colorScheme)
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
        // `contentMargins` reaches every scroll view below, including those inside a `NavigationStack`;
        // a `safeAreaInset` on the stack doesn't reliably reach its pushed `List`s.
        content
            .contentMargins(.bottom, inset, for: .scrollContent)
            .contentMargins(.bottom, inset, for: .scrollIndicators)
    }
}

public extension View {
    /// Makes the mini player content the source of the full player's zoom transition.
    ///
    /// - iOS 26: the accessory's own glass is the source; no background of ours covers it.
    /// - iOS 18: the zoom snapshots the source, so it gets the bar's background and corners (a solid color: the
    ///   source only takes `Color` backgrounds), otherwise collapsing ends on a plain sharp-cornered rectangle.
    @ViewBuilder
    func miniPlayerTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                matchedTransitionSource(id: id, in: namespace)
            } else {
                legacyMiniPlayerTransitionSource(id: id, in: namespace)
            }
        #else
            legacyMiniPlayerTransitionSource(id: id, in: namespace)
        #endif
    }

    private func legacyMiniPlayerTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        matchedTransitionSource(id: id, in: namespace) { source in
            source
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
        }
    }
}

/// Text and glyph styles of the mini player's content.
///
/// - iOS 26: hierarchical styles. The accessory's glass picks its light or dark look from what is behind it and
///   makes hierarchical content legible on it; a fixed `UIColor` resolves on its own and came out white on light
///   glass over a dark cover.
/// - iOS 18: the semantic label colors on the material bar.
public enum MiniPlayerStyle {
    public static var primary: AnyShapeStyle {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                AnyShapeStyle(.primary)
            } else {
                AnyShapeStyle(SemanticColor.textPrimary)
            }
        #else
            AnyShapeStyle(SemanticColor.textPrimary)
        #endif
    }

    public static var secondary: AnyShapeStyle {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                AnyShapeStyle(.secondary)
            } else {
                AnyShapeStyle(SemanticColor.textSecondary)
            }
        #else
            AnyShapeStyle(SemanticColor.textSecondary)
        #endif
    }
}

/// The mini player's artwork. 44 pt on the iOS 18 bar; on iOS 26 it is sized for the bottom accessory,
/// smaller when the accessory sits inline next to a minimized tab bar.
public struct MiniPlayerArtwork: View {
    private let url: URL?

    public init(url: URL?) {
        self.url = url
    }

    public var body: some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                AccessoryArtwork(url: url)
            } else {
                ArtworkView(url: url, size: .mini)
            }
        #else
            ArtworkView(url: url, size: .mini)
        #endif
    }
}

public extension View {
    /// Horizontal insets of the mini player's content row.
    ///
    /// - iOS 18: 8 pt inside the rounded bar.
    /// - iOS 26: the capsule's round ends make an inset equal to the artwork's top and bottom inset look
    ///   cramped, so the artwork sits further in; the trailing buttons' 44 pt frames already bring their own room.
    @ViewBuilder
    func miniPlayerContentPadding() -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                modifier(AccessoryContentPadding())
            } else {
                padding(.horizontal, Spacing.s)
            }
        #else
            padding(.horizontal, Spacing.s)
        #endif
    }
}

#if compiler(>=6.2)
    @available(iOS 26, *)
    private struct AccessoryArtwork: View {
        let url: URL?
        @Environment(\.tabViewBottomAccessoryPlacement) private var placement

        var body: some View {
            ArtworkView(url: url, size: .custom(placement == .inline ? 24 : 32))
        }
    }

    @available(iOS 26, *)
    private struct AccessoryContentPadding: ViewModifier {
        @Environment(\.tabViewBottomAccessoryPlacement) private var placement

        func body(content: Content) -> some View {
            // Expanded: a 48 pt capsule, 32 pt artwork 8 pt from the top and bottom. At 14 pt from the leading end
            // the gap between the artwork's corner and the capsule's curve is about as wide as those 8 pt
            // (at 8 pt the corner almost touched the curve). Inline: a 46 pt capsule and 24 pt artwork.
            // The trailing padding puts the next-track glyph as far from its end as the artwork is from its own.
            let inline = placement == .inline
            content
                .padding(.leading, inline ? 12 : 14)
                .padding(.trailing, inline ? 5 : 7)
        }
    }
#endif
