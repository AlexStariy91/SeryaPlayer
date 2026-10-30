import DesignSystem
import Domain
import SwiftUI

/// Bottom row: shuffle, repeat, AirPlay, equalizer, queue.
struct PlayerActions: View {
    let viewModel: PlayerViewModel
    let onShowEqualizer: () -> Void
    let onShowQueue: () -> Void

    var body: some View {
        HStack {
            ToggleIconButton(systemImage: "shuffle", isOn: snapshot.isShuffled, action: viewModel.toggleShuffle)
                .accessibilityLabel(Text("Shuffle", bundle: .module))
                .accessibilityValue(snapshot.isShuffled ? Text("On", bundle: .module) : Text("Off", bundle: .module))
            Spacer()
            ToggleIconButton(
                systemImage: snapshot.repeatMode == .one ? "repeat.1" : "repeat",
                isOn: snapshot.repeatMode != .off,
                action: viewModel.cycleRepeatMode
            )
            .accessibilityLabel(Text("Repeat", bundle: .module))
            .accessibilityValue(repeatValue)
            Spacer()
            RoutePickerButton()
                .frame(width: 44, height: 44)
            Spacer()
            ToggleIconButton(systemImage: "slider.vertical.3", isOn: false, action: onShowEqualizer)
                .overlay(alignment: .topTrailing) {
                    if viewModel.isEqualizerActive {
                        Circle()
                            .fill(.white)
                            .frame(width: 7, height: 7)
                            .offset(x: -6, y: 6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: viewModel.isEqualizerActive)
                .accessibilityLabel(Text("Equalizer", bundle: .module))
                .accessibilityValue(viewModel.isEqualizerActive ? Text("On", bundle: .module) : Text("Off", bundle: .module))
            Spacer()
            ToggleIconButton(systemImage: "list.bullet", isOn: false, action: onShowQueue)
                .accessibilityLabel(Text("Queue", bundle: .module))
        }
        .sensoryFeedback(.selection, trigger: snapshot.isShuffled)
        .sensoryFeedback(.selection, trigger: snapshot.repeatMode)
    }

    private var snapshot: PlaybackSnapshot {
        viewModel.snapshot
    }

    private var repeatValue: Text {
        switch snapshot.repeatMode {
        case .off: Text("Off", bundle: .module)
        case .all: Text("All", bundle: .module)
        case .one: Text("One", bundle: .module)
        }
    }
}

/// A 44 pt icon button; when on, the icon sits on a translucent rounded square.
private struct ToggleIconButton: View {
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                            .fill(.white.opacity(0.2))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
