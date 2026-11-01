import SwiftUI
import UIKit

/// Holds the latest levels and hands them to the bars' layers. Not observable on purpose: showing a
/// frame must not invalidate any SwiftUI view.
@MainActor
final class SpectrumBarsController {
    /// Reused for every frame; replaced only if the band count changes.
    private(set) var levels: [Float]
    fileprivate weak var view: SpectrumBarsUIView?

    init(levels: [Float]) {
        self.levels = levels
    }

    func show(_ values: [Float]) {
        if values.count == levels.count {
            for index in values.indices {
                levels[index] = values[index]
            }
        } else {
            levels = values
        }
        view?.layoutBars()
    }
}

/// The bars as Core Animation layers: one gradient, masked by a rounded layer per band.
struct SpectrumBarsView: UIViewRepresentable {
    let controller: SpectrumBarsController
    let colors: [Color]

    func makeUIView(context _: Context) -> SpectrumBarsUIView {
        let view = SpectrumBarsUIView(controller: controller)
        controller.view = view
        return view
    }

    func updateUIView(_ view: SpectrumBarsUIView, context: Context) {
        controller.view = view
        // Resolve in SwiftUI's environment: the full player forces a dark scheme that UIKit's
        // current traits don't know about, and the palette and accent colors are dynamic.
        view.setColors(colors.map { $0.resolve(in: context.environment).cgColor })
    }
}

final class SpectrumBarsUIView: UIView {
    private let controller: SpectrumBarsController
    private let gradient = CAGradientLayer()
    private let barMask = CALayer()
    private var bars: [CALayer] = []
    private var colors: [CGColor] = []

    init(controller: SpectrumBarsController) {
        self.controller = controller
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        gradient.mask = barMask
        layer.addSublayer(gradient)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setColors(_ newColors: [CGColor]) {
        guard newColors != colors else { return }
        colors = newColors
        gradient.colors = newColors
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        barMask.frame = bounds
        CATransaction.commit()
        layoutBars()
    }

    /// Sizes each band's layer from the controller's levels without implicit animations.
    func layoutBars() {
        let levels = controller.levels
        if bars.count != levels.count {
            bars.forEach { $0.removeFromSuperlayer() }
            bars = levels.map { _ in
                let bar = CALayer()
                bar.backgroundColor = UIColor.white.cgColor
                bar.cornerCurve = .continuous
                barMask.addSublayer(bar)
                return bar
            }
        }
        let size = bounds.size
        guard !levels.isEmpty, size.width > 0, size.height > 0 else { return }
        let pitch = size.width / CGFloat(levels.count)
        let width = pitch * 0.62
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            // A level of 0 leaves a round dot: the resting state while paused.
            let height = max(width, CGFloat(min(max(levels[index], 0), 1)) * size.height)
            bar.frame = CGRect(
                x: CGFloat(index) * pitch + (pitch - width) / 2,
                y: (size.height - height) / 2,
                width: width,
                height: height
            )
            bar.cornerRadius = width / 2
        }
        CATransaction.commit()
    }
}
