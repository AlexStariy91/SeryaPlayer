import SwiftUI

/// Playback position: a capsule that thickens while dragged, with elapsed and remaining time underneath.
/// Reports the value only when the finger lifts, so seeking doesn't spam the player.
/// `center` sits between the two time labels; `rate` scales the remaining time (wall-clock time left).
public struct TimelineSlider<Center: View>: View {
    private let current: TimeInterval
    private let duration: TimeInterval
    private let rate: Double
    private let center: Center
    private let onSeek: (TimeInterval) -> Void
    private let onScrubbingChanged: (Bool) -> Void

    @State private var dragValue: TimeInterval?

    public init(
        current: TimeInterval,
        duration: TimeInterval,
        rate: Double = 1,
        onScrubbingChanged: @escaping (Bool) -> Void = { _ in },
        onSeek: @escaping (TimeInterval) -> Void,
        @ViewBuilder center: () -> Center
    ) {
        self.current = current
        self.duration = duration
        self.rate = max(rate, 0.1)
        self.center = center()
        self.onScrubbingChanged = onScrubbingChanged
        self.onSeek = onSeek
    }

    private var isDragging: Bool {
        dragValue != nil
    }

    private var displayed: TimeInterval {
        min(max(dragValue ?? current, 0), max(duration, 0))
    }

    private var fraction: Double {
        duration > 0 ? displayed / duration : 0
    }

    public var body: some View {
        VStack(spacing: Spacing.xs) {
            GeometryReader { proxy in
                let height: CGFloat = isDragging ? 12 : 6
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(SemanticColor.fill)
                    Capsule().fill(.tint.opacity(isDragging ? 1 : 0.85))
                        .frame(width: max(height, width * fraction))
                }
                .frame(height: height)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragValue == nil {
                                onScrubbingChanged(true)
                            }
                            let ratio = min(max(value.location.x / max(width, 1), 0), 1)
                            dragValue = ratio * duration
                        }
                        .onEnded { value in
                            let ratio = min(max(value.location.x / max(width, 1), 0), 1)
                            dragValue = nil
                            onScrubbingChanged(false)
                            onSeek(ratio * duration)
                        }
                )
                .animation(.snappy(duration: 0.2), value: isDragging)
            }
            .frame(height: 28)

            HStack {
                Text(TimeFormat.clock(displayed))
                    .frame(maxWidth: .infinity, alignment: .leading)
                center
                Text("-" + TimeFormat.clock((duration - displayed) / rate))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(AppFont.time)
            .foregroundStyle(SemanticColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Playback position", bundle: .module))
        .accessibilityValue(Text("\(TimeFormat.spoken(displayed)) of \(TimeFormat.spoken(duration))", bundle: .module))
        .accessibilityAdjustableAction { direction in
            let step = max(duration / 20, 5)
            switch direction {
            case .increment: onSeek(min(displayed + step, duration))
            case .decrement: onSeek(max(displayed - step, 0))
            @unknown default: break
            }
        }
    }
}

public extension TimelineSlider where Center == EmptyView {
    init(
        current: TimeInterval,
        duration: TimeInterval,
        onScrubbingChanged: @escaping (Bool) -> Void = { _ in },
        onSeek: @escaping (TimeInterval) -> Void
    ) {
        self.init(current: current, duration: duration, onScrubbingChanged: onScrubbingChanged, onSeek: onSeek) {
            EmptyView()
        }
    }
}

#Preview("Timeline") {
    TimelineSlider(current: 83, duration: 245) { _ in }
        .padding()
}
