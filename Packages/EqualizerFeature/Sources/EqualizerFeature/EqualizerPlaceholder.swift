import DesignSystem
import Domain
import SwiftUI

/// Tab/screen placeholder. Replaced by the real feature in its stage.
public struct EqualizerPlaceholderView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView("Equalizer", systemImage: "hammer", description: Text("Coming soon"))
    }
}
