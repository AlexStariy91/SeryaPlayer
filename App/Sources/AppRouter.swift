import Observation

/// Navigation between features. Features don't know about each other; everything goes through the router.
@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case library, folders, browser
    }

    var selectedTab: Tab = .library
    var isPlayerPresented = false
}
