#if DEBUG
    import SwiftUI

    #Preview("Curve") {
        @Previewable @State var gains: [Float] = [4, 3, 1, 0, -1, 0, 1, 3, 4, 5]
        EQCurveView(gains: gains, isEnabled: true, onChange: { band, gain in gains[band] = gain }, onEditingChanged: { _ in })
            .padding()
    }
#endif
