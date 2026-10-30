import MediaPlayer
import SwiftUI

/// System volume slider (`MPVolumeView`): the only way to change the device volume from an app.
/// The simulator has no volume control, so it renders empty there.
struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context _: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.tintColor = .white
        return view
    }

    func updateUIView(_: MPVolumeView, context _: Context) {}
}
