import DesignSystem
import Domain
import SwiftUI

/// Tab/screen placeholder. Replaced by the real feature in its stage.
public struct BrowserPlaceholderView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView("Browser", systemImage: "hammer", description: Text("Coming soon"))
    }
}
