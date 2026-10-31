import DesignSystem
import Domain
import SwiftUI

/// One near-full-height detent, laid out like an inset-grouped Settings screen: the on/off row, the curve,
/// the presets, then the band sliders and the preamp. Landscape puts the curve and bands beside the switch and presets.
struct EqualizerSheet: View {
    @State private var viewModel: EqualizerViewModel
    @State private var edit: PresetEdit?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss

    /// Keeps labels and their controls close together on wide screens.
    private static let maxContentWidth: CGFloat = 700

    init(viewModel: EqualizerViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var isEnabled: Bool {
        viewModel.settings.isEnabled
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if verticalSizeClass == .compact {
                        landscape
                    } else {
                        portrait
                    }
                }
                .frame(maxWidth: Self.maxContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(GroupedColor.background)
            .navigationTitle(Text("Equalizer", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done", bundle: .module)) { dismiss() }
                }
            }
        }
        // The player stays visible above; everything is reachable by scrolling, nothing hides behind a detent.
        .presentationDetents([.fraction(0.9)])
        .presentationDragIndicator(.visible)
        .presetEditAlerts(viewModel: viewModel, edit: $edit)
        .task { await viewModel.start() }
    }

    // MARK: - Layouts

    private var portrait: some View {
        VStack(spacing: Spacing.xl) {
            enabledSection
            curveCard
            presetsSection
            bandsSection
        }
    }

    private var landscape: some View {
        HStack(alignment: .top, spacing: Spacing.l) {
            VStack(spacing: Spacing.xl) {
                curveCard
                bandsSection
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: Spacing.xl) {
                enabledSection
                presetsSection
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Sections

    private var enabledSection: some View {
        GroupedSection {
            Toggle(isOn: Binding(get: { isEnabled }, set: { viewModel.setEnabled($0) })) {
                Text("Equalizer", bundle: .module)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .frame(minHeight: 44)
            .accessibilityIdentifier("equalizer.enabled")
        } footer: {
            if !isEnabled {
                // Applying a preset turns the equalizer on (`ApplyEQPresetUseCase`), so the chips stay active.
                Text("Choosing a preset turns the equalizer on.", bundle: .module)
            }
        }
    }

    private var curveCard: some View {
        GroupedSection {
            EQCurveView(
                gains: viewModel.settings.gains,
                isEnabled: isEnabled,
                onChange: { band, gain in viewModel.setGain(band: band, gain: gain) },
                onEditingChanged: { viewModel.setEditing($0) }
            )
            .frame(height: verticalSizeClass == .compact ? 140 : 160)
            .padding(.vertical, Spacing.s)
            // Off: let drags scroll the sheet instead of being swallowed by the curve.
            .allowsHitTesting(isEnabled)
        }
    }

    private var presetsSection: some View {
        GroupedSection {
            PresetChipsView(viewModel: viewModel, edit: $edit)
        } header: {
            Text("Presets", bundle: .module)
        }
    }

    private var bandsSection: some View {
        GroupedSection {
            BandSlidersView(viewModel: viewModel)
                .padding(Spacing.m)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.4)
                .allowsHitTesting(isEnabled)
        } header: {
            Text("Bands", bundle: .module)
        }
    }
}

// MARK: - Grouped style

private enum GroupedColor {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

/// An inset-grouped section like Settings: an optional header, a rounded card and an optional footer.
private struct GroupedSection<Content: View, Header: View, Footer: View>: View {
    @ViewBuilder let content: Content
    @ViewBuilder let header: Header
    @ViewBuilder let footer: Footer

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header = { EmptyView() },
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.content = content()
        self.header = header()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            header
                .font(.footnote)
                .textCase(.uppercase)
                .foregroundStyle(SemanticColor.textSecondary)
                .padding(.horizontal, Spacing.l)
                .accessibilityAddTraits(.isHeader)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GroupedColor.card, in: RoundedRectangle(cornerRadius: Radius.m, style: .continuous))
            footer
                .font(.footnote)
                .foregroundStyle(SemanticColor.textSecondary)
                .padding(.horizontal, Spacing.l)
        }
    }
}
