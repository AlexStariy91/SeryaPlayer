import DesignSystem
import SwiftUI

/// The Play / Shuffle pair under a collection header.
struct PlayShuffleButtons: View {
    let isEnabled: Bool
    let onPlay: () -> Void
    let onShuffle: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            Button(action: onPlay) {
                Label(String(localized: "Play", bundle: .module), systemImage: "play.fill")
                    // Without it the symbol takes the tint on iOS 18 and vanishes into the prominent fill.
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .adaptiveButtonStyle(prominent: true)
            .accessibilityIdentifier("collection.play")
            Button(action: onShuffle) {
                Label(String(localized: "Shuffle", bundle: .module), systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .adaptiveButtonStyle()
            .accessibilityIdentifier("collection.shuffle")
        }
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}
