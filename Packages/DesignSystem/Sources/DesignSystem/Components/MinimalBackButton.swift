import SwiftUI
import UIKit

public extension View {
    /// Pushes from this screen show a back arrow without a label, in every mode (normal, Select, Select All).
    /// The back item belongs to the screen you came from, so apply this to the root and to every screen that
    /// pushes. Unlike `.toolbarRole(.editor)` on the pushed screen, the item is fixed before the transition starts.
    func minimalBackButton() -> some View {
        background { MinimalBackButtonBridge().frame(width: 0, height: 0) }
    }
}

private struct MinimalBackButtonBridge: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_: Controller, context _: Context) {}

    final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        /// The controller directly inside the navigation controller is the one whose `navigationItem` the stack uses.
        private func apply() {
            var current: UIViewController? = self
            while let controller = current {
                if controller.parent is UINavigationController {
                    controller.navigationItem.backButtonDisplayMode = .minimal
                    return
                }
                current = controller.parent
            }
        }
    }
}
