import AVFoundation
import DesignSystem
import MediaPlayer
import SwiftUI

/// Device volume as a capsule that matches the timeline: no thumb, rounded ends, thickens while dragged.
///
/// Apps can only change the system volume through `MPVolumeView`, so a hidden one stays in the hierarchy
/// (it also keeps the system volume HUD away) and its slider is driven from here. The current value comes
/// from `AVAudioSession.outputVolume`, so hardware buttons move the capsule too.
/// The simulator has no output volume: the capsule renders but doesn't change anything.
struct VolumeSlider: View {
    @State private var volume = SystemVolume()
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let height: CGFloat = isDragging ? 12 : 6
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(SemanticColor.fill)
                Capsule().fill(.tint.opacity(isDragging ? 1 : 0.85))
                    .frame(width: max(height, width * CGFloat(volume.value)))
            }
            .frame(height: height)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        volume.set(Float(min(max(value.location.x / max(width, 1), 0), 1)))
                    }
                    .onEnded { _ in isDragging = false }
            )
            .animation(.snappy(duration: 0.2), value: isDragging)
        }
        .background(alignment: .topLeading) {
            HiddenVolumeView(volume: volume)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Volume", bundle: .module))
        .accessibilityValue(Text(volume.value, format: .percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: volume.set(min(volume.value + 0.0625, 1))
            case .decrement: volume.set(max(volume.value - 0.0625, 0))
            @unknown default: break
            }
        }
        .task { await volume.observe() }
    }
}

/// The system output volume and the slider of the hidden `MPVolumeView` that changes it.
@MainActor
@Observable
final class SystemVolume {
    private(set) var value: Float = AVAudioSession.sharedInstance().outputVolume
    @ObservationIgnored weak var slider: UISlider?

    func set(_ newValue: Float) {
        value = newValue
        slider?.setValue(newValue, animated: false)
        slider?.sendActions(for: .valueChanged)
    }

    /// Follows hardware buttons and Control Center until cancelled.
    func observe() async {
        let stream = AsyncStream<Float> { continuation in
            let observation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { _, change in
                if let volume = change.newValue {
                    continuation.yield(volume)
                }
            }
            continuation.onTermination = { _ in observation.invalidate() }
        }
        for await volume in stream where abs(volume - value) > 0.001 {
            value = volume
        }
    }
}

private struct HiddenVolumeView: UIViewRepresentable {
    let volume: SystemVolume

    func makeUIView(context _: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        volume.slider = view.subviews.compactMap { $0 as? UISlider }.first
        return view
    }

    func updateUIView(_ view: MPVolumeView, context _: Context) {
        if volume.slider == nil {
            volume.slider = view.subviews.compactMap { $0 as? UISlider }.first
        }
    }
}
