import DesignSystem
import Domain
import Shared
import SwiftUI

/// Composition Root: the only place where DataLayer and Playback implementations are assembled.
/// Features receive only Domain protocols and use cases through their factories.
@MainActor
@Observable
final class AppContainer {
    let flags: FeatureFlags
    let router = AppRouter()

    init(flags: FeatureFlags) {
        self.flags = flags
    }

    /// `-uiTesting` launches with test data (in-memory store, fixtures).
    static func make(arguments: [String]) -> AppContainer {
        if arguments.contains("-uiTesting") {
            return PreviewContainer.make()
        }
        return AppContainer(flags: .default)
    }
}

/// Container for previews and UI tests: in-memory repositories and mocks of the same protocols.
/// TODO(stage-2/3): plug in in-memory implementations once DataLayer and Playback land.
enum PreviewContainer {
    @MainActor
    static func make() -> AppContainer {
        AppContainer(flags: .default)
    }
}
