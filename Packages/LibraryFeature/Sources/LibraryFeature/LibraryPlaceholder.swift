import DesignSystem
import Domain
import SwiftUI

/// Placeholder still used by `RootView` until the orchestrator wires `LibraryFeature.makeRootView`.
/// Delete it in the same change.
public struct LibraryPlaceholderView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView("Library", systemImage: "hammer", description: Text("Coming soon"))
    }
}
