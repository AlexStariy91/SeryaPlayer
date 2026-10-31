import DesignSystem
import Domain
import SwiftUI

/// Medium detent: on/off, presets and the curve. Large detent (or landscape): plus band sliders and preamp.
struct EqualizerSheet: View {
    @State private var viewModel: EqualizerViewModel
    @State private var detent: PresentationDetent
    @State private var edit: PresetEdit?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss

    init(viewModel: EqualizerViewModel, detent: PresentationDetent = .medium) {
        _viewModel = State(initialValue: viewModel)
        _detent = State(initialValue: detent)
    }

    private var isCompact: Bool {
        verticalSizeClass == .compact
    }

    private var showsBands: Bool {
        detent == .large || isCompact
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.l) {
                    if isCompact {
                        // Landscape: the curve and the bands on the left, the presets beside them.
                        HStack(alignment: .top, spacing: Spacing.xl) {
                            VStack(spacing: Spacing.l) {
                                curve.frame(height: 150)
                                if showsBands {
                                    BandSlidersView(viewModel: viewModel)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            chips(wrapped: true)
                                .frame(width: 290)
                        }
                        .padding(.horizontal, Spacing.screenMargin)
                    } else {
                        curve
                            .frame(height: 170)
                            .padding(.horizontal, Spacing.screenMargin)
                        chips(wrapped: false)
                        if showsBands {
                            BandSlidersView(viewModel: viewModel)
                                .padding(.horizontal, Spacing.screenMargin)
                        }
                    }
                }
                .padding(.vertical, Spacing.s)
            }
            .navigationTitle(Text("Equalizer", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The switch sits in the bar next to the title instead of a row of its own: it stays
                // close to its label in landscape and leaves the medium detent to the curve and presets.
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: Binding(get: { viewModel.settings.isEnabled }, set: { viewModel.setEnabled($0) })) {
                        Text("Equalizer", bundle: .module)
                    }
                    // Toolbars render toggles as buttons by default.
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", bundle: .module)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presetEditAlerts(viewModel: viewModel, edit: $edit)
        .task { await viewModel.start() }
    }

    private var curve: some View {
        EQCurveView(
            gains: viewModel.settings.gains,
            isEnabled: viewModel.settings.isEnabled,
            onChange: { band, gain in viewModel.setGain(band: band, gain: gain) },
            onEditingChanged: { viewModel.setEditing($0) }
        )
    }

    private func chips(wrapped: Bool) -> some View {
        PresetChipsView(viewModel: viewModel, edit: $edit, isWrapped: wrapped)
    }
}
