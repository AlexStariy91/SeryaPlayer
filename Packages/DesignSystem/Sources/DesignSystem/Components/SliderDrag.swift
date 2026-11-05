import SwiftUI
import UIKit

public extension View {
    /// The touch handling of the capsule sliders (timeline, volume). Reports the finger's x in the view's own
    /// coordinates while it moves (`onChanged`) and when it lifts (`onEnded`); a tap reports both once.
    ///
    /// - iOS 26: a pan that begins only when the finger moves more sideways than up or down, plus a tap. A vertical
    ///   swipe that starts on the slider then goes to the full player's zoom-transition dismiss pan instead, like in
    ///   Apple Music. A `DragGesture` claims the touch as soon as it lands and blocks that pan.
    /// - iOS 18: a `DragGesture` with no minimum distance, unchanged.
    func sliderDrag(
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping (CGFloat) -> Void
    ) -> some View {
        modifier(SliderDragModifier(onChanged: onChanged, onEnded: onEnded))
    }
}

private struct SliderDragModifier: ViewModifier {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                content
                    .gesture(HorizontalPan(onChanged: onChanged, onEnded: onEnded))
                    .simultaneousGesture(
                        SpatialTapGesture().onEnded { value in
                            onChanged(value.location.x)
                            onEnded(value.location.x)
                        }
                    )
            } else {
                legacy(content)
            }
        #else
            legacy(content)
        #endif
    }

    private func legacy(_ content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { onChanged($0.location.x) }
                .onEnded { onEnded($0.location.x) }
        )
    }
}

#if compiler(>=6.2)
    /// A one-finger pan that refuses to begin for mostly vertical movement (the standard UIKit way to share a
    /// screen with a vertical system pan: `gestureRecognizerShouldBegin`).
    @available(iOS 26, *)
    private struct HorizontalPan: UIGestureRecognizerRepresentable {
        let onChanged: (CGFloat) -> Void
        let onEnded: (CGFloat) -> Void

        func makeCoordinator(converter _: CoordinateSpaceConverter) -> Coordinator {
            Coordinator()
        }

        func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
            let pan = UIPanGestureRecognizer()
            pan.maximumNumberOfTouches = 1
            pan.delegate = context.coordinator
            return pan
        }

        func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
            let x = context.converter.localLocation.x
            switch recognizer.state {
            case .began, .changed:
                onChanged(x)
            case .ended, .cancelled:
                onEnded(x)
            default:
                break
            }
        }

        @MainActor
        final class Coordinator: NSObject, UIGestureRecognizerDelegate {
            func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
                guard let pan = recognizer as? UIPanGestureRecognizer else {
                    return true
                }
                let translation = pan.translation(in: pan.view)
                return abs(translation.x) > abs(translation.y)
            }
        }
    }
#endif
