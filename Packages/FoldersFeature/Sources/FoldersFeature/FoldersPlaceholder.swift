import DesignSystem
import Domain
import SwiftUI

/// Tab/screen placeholder. Replaced by the real feature in its stage.
public struct FoldersPlaceholderView: View {
    public init() {}

    public var body: some View {
        ContentUnavailableView("Folders", systemImage: "hammer", description: Text("Coming soon"))
    }
}
