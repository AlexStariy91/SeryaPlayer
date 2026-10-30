import DesignSystem
import Domain
import SwiftUI

/// Content of the mini player: artwork, title and artist, play/pause and next. Tapping it opens the full player.
/// The bar itself (material or glass, placement above the tab bar) comes from DesignSystem's `miniPlayerHost`.
struct MiniPlayerView: View {
    let viewModel: PlayerViewModel
    let onOpen: () -> Void

    @State private var playTaps = 0
    @State private var nextTaps = 0

    var body: some View {
        HStack(spacing: Spacing.m) {
            Button(action: onOpen) {
                HStack(spacing: Spacing.m) {
                    ArtworkView(url: viewModel.thumbnailURL, size: .mini)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(viewModel.track?.title ?? String(localized: "Not Playing", bundle: .module))
                            .font(AppFont.rowTitle)
                            .foregroundStyle(SemanticColor.textPrimary)
                        if let artist = viewModel.track?.artist, !artist.isEmpty {
                            Text(artist)
                                .font(AppFont.rowSubtitle)
                                .foregroundStyle(SemanticColor.textSecondary)
                        }
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the full player", bundle: .module))

            Button {
                playTaps += 1
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.snapshot.isPlaying ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(viewModel.snapshot.isPlaying ? Text("Pause", bundle: .module) : Text("Play", bundle: .module))

            Button {
                nextTaps += 1
                viewModel.next()
            } label: {
                Image(systemName: "forward.fill")
                    .symbolEffect(.bounce, value: nextTaps)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Next Track", bundle: .module))
        }
        .font(.title3)
        .foregroundStyle(SemanticColor.textPrimary)
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.s)
        .frame(maxHeight: .infinity)
        .sensoryFeedback(.impact(weight: .light), trigger: nextTaps)
        .sensoryFeedback(.impact(weight: .light), trigger: playTaps)
    }
}

#Preview("Mini player") {
    let preview = PreviewPlayer.playing()
    VStack {
        Spacer()
        MiniPlayerView(viewModel: preview.viewModel) {}
            .frame(height: 60)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.l, style: .continuous))
            .padding(Spacing.s)
    }
    .task { await preview.viewModel.observe() }
}
