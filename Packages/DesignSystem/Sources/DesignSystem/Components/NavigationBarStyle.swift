import UIKit

/// App-wide navigation bar tweaks that UIKit offers no SwiftUI equivalent for.
public enum NavigationBarStyle {
    /// Shows the back button as a bare chevron by making the back title transparent.
    ///
    /// The title must stay (just invisible): UIKit animates the chevron together with the "large title → back
    /// label" morph on pushes from large-title screens. With the label really hidden (`backButtonDisplayMode =
    /// .minimal`, `.toolbarRole(.editor)`, an empty title) the chevron dips to the large-title baseline for a few
    /// frames and snaps back up. Don't "simplify" this to one of those.
    ///
    /// Only the back button appearance is set; `UIBarButtonItem.appearance()` is left alone so "Select" and other
    /// items keep their titles. Call once at launch.
    @MainActor
    public static func hideBackButtonTitles() {
        let back = UIBarButtonItemAppearance(style: .plain)
        for state in [back.normal, back.highlighted, back.disabled, back.focused] {
            state.titleTextAttributes = [.foregroundColor: UIColor.clear]
        }
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance(back: back, edge: false)
        bar.compactAppearance = appearance(back: back, edge: false)
        bar.scrollEdgeAppearance = appearance(back: back, edge: true)
    }

    /// A fresh appearance with the background the bar has by default, so only the back button changes.
    /// On iOS 26 the default is already right (and keeps Liquid Glass), so nothing is configured there; before it,
    /// the scroll-edge bar is transparent.
    @MainActor
    private static func appearance(back: UIBarButtonItemAppearance, edge: Bool) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        if #unavailable(iOS 26) {
            if edge {
                appearance.configureWithTransparentBackground()
            } else {
                appearance.configureWithDefaultBackground()
            }
        }
        appearance.backButtonAppearance = back
        return appearance
    }
}
