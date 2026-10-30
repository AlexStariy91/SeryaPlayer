import DesignSystem
import Domain
import SwiftUI

/// Ten vertical sliders and the preamp.
struct BandSlidersView: View {
    let viewModel: EqualizerViewModel

    var body: some View {
        VStack(spacing: Spacing.l) {
            HStack(spacing: 0) {
                ForEach(EQBands.frequencies.indices, id: \.self) { band in
                    VerticalGainSlider(
                        gain: Binding(
                            get: { Double(viewModel.settings.gains[safe: band] ?? 0) },
                            set: { viewModel.setGain(band: band, gain: Float($0)) }
                        ),
                        label: Strings.frequency(EQBands.frequencies[band])
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .disabled(!viewModel.settings.isEnabled)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("Preamp", bundle: .module)
                    Spacer()
                    Text(String(format: "%+.1f dB", viewModel.settings.preamp))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(viewModel.settings.preamp) },
                        set: { viewModel.setPreamp(Float($0)) }
                    ),
                    in: Double(EQBands.gainRange.lowerBound) ... Double(EQBands.gainRange.upperBound),
                    step: 0.5
                )
                .accessibilityLabel(Text("Preamp", bundle: .module))
            }
            .disabled(!viewModel.settings.isEnabled)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
