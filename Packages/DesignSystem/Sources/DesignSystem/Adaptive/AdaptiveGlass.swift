import SwiftUI

// The only place where iOS version checks live. Feature code contains no #available.
//
// `#if compiler(>=6.2)` is needed while the project still builds with Xcode 16 (iOS 18 SDK),
// which lacks the Liquid Glass APIs. With Xcode 26 the iOS 26 branch compiles and is used at runtime.

public extension View {
    /// Glass on iOS 26, material on iOS 18.
    @ViewBuilder
    func adaptiveGlass(in shape: some Shape = Capsule(), interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
            } else {
                background(.ultraThinMaterial, in: shape)
            }
        #else
            background(.ultraThinMaterial, in: shape)
        #endif
    }

    /// `.glass` / `.glassProminent` on iOS 26, `.bordered` / `.borderedProminent` on iOS 18.
    @ViewBuilder
    func adaptiveButtonStyle(prominent: Bool = false) -> some View {
        #if compiler(>=6.2)
            if #available(iOS 26, *) {
                if prominent {
                    buttonStyle(.glassProminent)
                } else {
                    buttonStyle(.glass)
                }
            } else {
                if prominent {
                    buttonStyle(.borderedProminent)
                } else {
                    buttonStyle(.bordered)
                }
            }
        #else
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        #endif
    }
}
