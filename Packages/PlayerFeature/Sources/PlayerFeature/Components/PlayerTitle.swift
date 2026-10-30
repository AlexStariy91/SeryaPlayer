import DesignSystem
import Domain
import SwiftUI

struct PlayerTitle: View {
    let track: Track?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(track?.title ?? String(localized: "Not Playing", bundle: .module))
                .font(AppFont.playerTitle)
                .foregroundStyle(.primary)
            if let artist = track?.artist, !artist.isEmpty {
                Text(artist)
                    .font(AppFont.playerSubtitle)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
