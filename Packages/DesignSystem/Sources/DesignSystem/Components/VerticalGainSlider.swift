import SwiftUI

/// A vertical gain slider (an equalizer band), ±12 dB by default. Snaps to 0 dB with haptic feedback.
public struct VerticalGainSlider: View {
    @Binding private var gain: Double
    private let range: ClosedRange<Double>
    private let label: String?

    @State private var isDragging = false

    private nonisolated static let snapThreshold = 0.6
    private nonisolated static let step = 0.5

    public init(gain: Binding<Double>, range: ClosedRange<Double> = -12 ... 12, label: String? = nil) {
        _gain = gain
        self.range = range
        self.label = label
    }

    private var isAtZero: Bool {
        gain == 0
    }

    public var body: some View {
        VStack(spacing: Spacing.s) {
            Text(Self.format(gain))
                .font(AppFont.time)
                .foregroundStyle(isDragging ? Color.accentColor : SemanticColor.textSecondary)
            track
            if let label {
                Text(label)
                    .font(AppFont.caption)
                    .foregroundStyle(SemanticColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isAtZero) { _, atZero in atZero && isDragging }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label ?? "Gain"))
        .accessibilityValue(Text(Self.format(gain)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: gain = min(gain + 1, range.upperBound)
            case .decrement: gain = max(gain - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }

    private var track: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let thumb: CGFloat = isDragging ? 28 : 24
            let usable = max(height - thumb, 1)
            let ratio = (gain - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbCenter = height - thumb / 2 - usable * ratio
            let zeroCenter = height - thumb / 2 - usable * ((0 - range.lowerBound) / (range.upperBound - range.lowerBound))
            ZStack {
                Capsule().fill(SemanticColor.fill).frame(width: 6)
                // Fill from the 0 dB line to the thumb.
                Capsule().fill(Color.accentColor)
                    .frame(width: 6, height: abs(thumbCenter - zeroCenter))
                    .position(x: proxy.size.width / 2, y: (thumbCenter + zeroCenter) / 2)
                Capsule().fill(SemanticColor.separator)
                    .frame(width: 16, height: 1.5)
                    .position(x: proxy.size.width / 2, y: zeroCenter)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .frame(width: thumb, height: thumb)
                    .position(x: proxy.size.width / 2, y: thumbCenter)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let position = min(max((height - thumb / 2 - value.location.y) / usable, 0), 1)
                        gain = Self.snap(range.lowerBound + position * (range.upperBound - range.lowerBound), range: range)
                    }
                    .onEnded { _ in isDragging = false }
            )
            .animation(.snappy(duration: 0.15), value: isDragging)
        }
        .frame(minHeight: 160)
        .frame(width: 44)
    }

    /// Rounds to 0.5 dB and pulls values near 0 dB to exactly 0.
    nonisolated static func snap(_ value: Double, range: ClosedRange<Double>) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        if abs(clamped) < snapThreshold {
            return 0
        }
        return (clamped / step).rounded() * step
    }

    nonisolated static func format(_ gain: Double) -> String {
        let value = gain == 0 ? "0" : String(format: "%+.1f", gain)
        return "\(value) dB"
    }
}

#Preview("Gain") {
    @Previewable @State var gain = 3.0
    VerticalGainSlider(gain: $gain, label: "1k")
        .padding()
}
