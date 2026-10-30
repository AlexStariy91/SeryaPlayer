import DesignSystem
import Domain
import SwiftUI

/// The full-screen player. One column in portrait; in landscape (compact height) the artwork is on
/// the left and the controls on the right. Dismissed by swiping down (zoom transition) or the grabber.
struct FullPlayerView<EqualizerSheet: View>: View {
    let viewModel: PlayerViewModel
    let equalizerSheet: () -> EqualizerSheet

    @State private var showsQueue = false
    @State private var showsEqualizer = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        GeometryReader { proxy in
            Group {
                if verticalSizeClass == .compact {
                    landscape(size: proxy.size)
                } else {
                    portrait(size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .overlay(alignment: .top) { grabber }
        .background { ArtworkBackground(colors: viewModel.backgroundColors) }
        .environment(\.colorScheme, .dark)
        .task { await viewModel.progress.run() }
        .sheet(isPresented: $showsQueue) {
            QueueView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsEqualizer, content: equalizerSheet)
    }

    private func portrait(size: CGSize) -> some View {
        let side = max(0, min(size.width - Spacing.xl * 2, size.height * 0.48))
        return VStack(spacing: 0) {
            Spacer(minLength: Spacing.xxl)
            PlayerArtwork(url: viewModel.artworkURL, isPlaying: viewModel.snapshot.isPlaying, side: side)
            Spacer(minLength: Spacing.l)
            controls(compact: false)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.s)
    }

    private func landscape(size: CGSize) -> some View {
        let side = max(0, min(size.height - Spacing.xl * 2, size.width * 0.42))
        return HStack(spacing: Spacing.xxl) {
            PlayerArtwork(url: viewModel.artworkURL, isPlaying: viewModel.snapshot.isPlaying, side: side)
                .frame(maxWidth: .infinity)
            controls(compact: true)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.l)
    }

    private func controls(compact: Bool) -> some View {
        VStack(spacing: compact ? Spacing.xs : Spacing.m) {
            PlayerTitle(track: viewModel.track)
            PlayerTimeline(progress: viewModel.progress, duration: viewModel.duration)
            TransportControls(viewModel: viewModel, compact: compact)
            VolumeRow()
            PlayerActions(
                viewModel: viewModel,
                onShowEqualizer: { showsEqualizer = true },
                onShowQueue: { showsQueue = true }
            )
        }
    }

    private var grabber: some View {
        Button {
            dismiss()
        } label: {
            Capsule()
                .fill(.white.opacity(0.5))
                .frame(width: 40, height: 5)
                .frame(width: 88, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close Player", bundle: .module))
    }
}

#Preview("Full player") {
    let preview = PreviewPlayer.playing()
    FullPlayerView(viewModel: preview.viewModel) {
        Text(verbatim: "Equalizer")
    }
    .task { await preview.viewModel.observe() }
}

#Preview("Full player, landscape", traits: .landscapeLeft) {
    let preview = PreviewPlayer.playing()
    FullPlayerView(viewModel: preview.viewModel) {
        Text(verbatim: "Equalizer")
    }
    .task { await preview.viewModel.observe() }
}
