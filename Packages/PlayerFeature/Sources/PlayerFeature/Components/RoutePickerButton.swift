import AVKit
import SwiftUI

/// AirPlay / Bluetooth output picker (`AVRoutePickerView`).
struct RoutePickerButton: UIViewRepresentable {
    func makeUIView(context _: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.prioritizesVideoDevices = false
        view.tintColor = UIColor.white.withAlphaComponent(0.8)
        view.activeTintColor = .white
        view.accessibilityLabel = String(localized: "AirPlay", bundle: .module)
        return view
    }

    func updateUIView(_: AVRoutePickerView, context _: Context) {}
}
