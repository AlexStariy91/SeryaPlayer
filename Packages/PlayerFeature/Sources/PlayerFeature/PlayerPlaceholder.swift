import DesignSystem
import Domain
import SwiftUI

public struct MiniPlayerPlaceholder: View {
    public init() {}

    public var body: some View {
        Label("Not Playing", systemImage: "music.note")
            .padding()
    }
}
