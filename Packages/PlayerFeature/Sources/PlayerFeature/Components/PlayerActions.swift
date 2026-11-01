import DesignSystem
import Domain
import SwiftUI

/// Bottom row: shuffle, repeat, AirPlay, equalizer, sleep timer, queue.
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
            SleepTimerButton(viewModel: viewModel)
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
            IconButtonLabel(systemImage: systemImage, isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private struct IconButtonLabel: View {
    let systemImage: String
    let isOn: Bool
    /// Shown instead of the icon, on a wider highlight (the sleep timer countdown).
    var text: String?

    var body: some View {
        Group {
            if let text {
                Text(text)
                    .font(.footnote.weight(.semibold).monospacedDigit())
            } else {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        // A fixed width, so the digits changing don't move the other buttons.
        .frame(width: text == nil ? 44 : 64, height: 44)
        .foregroundStyle(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .background {
            if isOn {
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .fill(.white.opacity(0.2))
            }
        }
    }
}

/// The sleep timer menu. A countdown shows the remaining time (mm:ss) on the highlight instead of the icon;
/// End of Track shows the filled icon on the highlight.
struct SleepTimerButton: View {
    let viewModel: PlayerViewModel

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: !isCountdown)) { context in
            Menu {
                ForEach(SleepTimerOption.all, id: \.self) { option in
                    Button {
                        viewModel.startSleepTimer(option)
                    } label: {
                        optionTitle(option)
                    }
                }
                if state.isActive {
                    Divider()
                    Button(role: .destructive, action: viewModel.cancelSleepTimer) {
                        Text("Off", bundle: .module)
                    }
                }
            } label: {
                IconButtonLabel(
                    systemImage: state.isActive ? "moon.zzz.fill" : "moon.zzz",
                    isOn: state.isActive,
                    text: countdownText(at: context.date)
                )
            }
            .menuIndicator(.hidden)
            // A Menu label takes the accent colour; the other buttons in the row are white or grey.
            .tint(state.isActive ? .primary : .secondary)
            .accessibilityLabel(Text("Sleep Timer", bundle: .module))
            .accessibilityValue(accessibilityValue(at: context.date))
            .accessibilityAddTraits(state.isActive ? .isSelected : [])
        }
        .animation(.snappy, value: state.isActive)
    }

    private var state: SleepTimerState {
        viewModel.sleepTimerState
    }

    private var isCountdown: Bool {
        if case .countdown = state {
            true
        } else {
            false
        }
    }

    private func optionTitle(_ option: SleepTimerOption) -> Text {
        switch option {
        case let .minutes(minutes): Text("\(minutes) min", bundle: .module)
        case .endOfTrack: Text("End of Track", bundle: .module)
        }
    }

    private func countdownText(at date: Date) -> String? {
        guard case let .countdown(deadline) = state else { return nil }
        return Self.format(deadline.timeIntervalSince(date))
    }

    private func accessibilityValue(at date: Date) -> Text {
        switch state {
        case .off: Text("Off", bundle: .module)
        case let .countdown(deadline): Text(Self.format(deadline.timeIntervalSince(date)))
        case .endOfTrack: Text("End of Track", bundle: .module)
        }
    }

    /// mm:ss, rounded up so the caption reads 0:01 until the very end.
    static func format(_ remaining: TimeInterval) -> String {
        let seconds = max(Int(remaining.rounded(.up)), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
