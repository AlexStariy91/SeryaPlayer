import DesignSystem
import Domain
import SwiftUI

/// Tab/screen placeholder. Replaced by the real feature in its stage.
public struct SettingsPlaceholderView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView("Settings", systemImage: "hammer", description: Text("Coming soon"))
    }
}
