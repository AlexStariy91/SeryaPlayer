import DesignSystem
import Domain
import SwiftUI

/// The only view that reads `PlaybackProgress`, so polling redraws nothing else.
struct PlayerTimeline: View {
    let progress: PlaybackProgress
    let duration: TimeInterval

    var body: some View {
        TimelineSlider(current: progress.currentTime, duration: duration, rate: Double(progress.rate)) { time in
            progress.seek(to: time)
        } center: {
            PlaybackRateButton(progress: progress)
        }
        .tint(.white)
    }
}

/// A small capsule with the current speed that opens the list of speeds. Quiet at 1×, highlighted
/// like the other active toggles at any other speed.
struct PlaybackRateButton: View {
    let progress: PlaybackProgress
    @Environment(\.locale) private var locale

    private var rate: Float {
        progress.rate
    }

    private var isActive: Bool {
        rate != PlaybackRate.normal
    }

    var body: some View {
        Menu {
            Picker(selection: Binding(get: { progress.rate }, set: { progress.setRate($0) })) {
                ForEach(PlaybackRate.options.reversed(), id: \.self) { option in
                    Text(Self.title(option, locale: locale)).tag(option)
                }
            } label: {
                Text("Playback Speed", bundle: .module)
            }
        } label: {
            Text(Self.title(rate, locale: locale))
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(isActive ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs)
                .background {
                    if isActive {
                        Capsule().fill(.white.opacity(0.2))
                    }
                }
                .frame(minWidth: 44, minHeight: 28)
                .contentShape(Rectangle())
        }
        .sensoryFeedback(.selection, trigger: rate)
        .accessibilityLabel(Text("Playback Speed", bundle: .module))
        .accessibilityValue(Text(Self.title(rate, locale: locale)))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// "1×", "1.5×", "0.75×".
    static func title(_ rate: Float, locale: Locale) -> String {
        rate.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale)) + "×"
    }
}
