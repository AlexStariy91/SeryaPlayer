import DesignSystem
import SwiftUI

struct VolumeRow: View {
    var body: some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: "speaker.fill")
            VolumeSlider()
                .frame(height: 34)
                .accessibilityLabel(Text("Volume", bundle: .module))
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .imageScale(.small)
    }
}
