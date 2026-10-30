import DesignSystem
import SwiftUI

/// Previous, play/pause and next.
struct TransportControls: View {
    let viewModel: PlayerViewModel
    var compact = false

    @State private var previousTaps = 0
    @State private var playTaps = 0
    @State private var nextTaps = 0
    @ScaledMetric(relativeTo: .largeTitle) private var playSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var skipSize: CGFloat = 30

    var body: some View {
        HStack {
            Spacer()
            Button {
                previousTaps += 1
                viewModel.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: skipSize * scale))
                    .symbolEffect(.bounce, value: previousTaps)
                    .frame(width: 64, height: 64)
            }
            .accessibilityLabel(Text("Previous Track", bundle: .module))
            Spacer()
            Button {
                playTaps += 1
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.snapshot.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: playSize * scale))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 80, height: 80)
            }
            .accessibilityLabel(viewModel.snapshot.isPlaying ? Text("Pause", bundle: .module) : Text("Play", bundle: .module))
            Spacer()
            Button {
                nextTaps += 1
                viewModel.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: skipSize * scale))
                    .symbolEffect(.bounce, value: nextTaps)
                    .frame(width: 64, height: 64)
            }
            .accessibilityLabel(Text("Next Track", bundle: .module))
            Spacer()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .sensoryFeedback(.impact(weight: .medium), trigger: playTaps)
        .sensoryFeedback(.impact(weight: .light), trigger: previousTaps)
        .sensoryFeedback(.impact(weight: .light), trigger: nextTaps)
    }

    private var scale: CGFloat {
        compact ? 0.8 : 1
    }
}
