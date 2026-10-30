import DesignSystem
import Domain
import SwiftUI

/// Preset chips: "Custom" first when the curve matches nothing, then built-in and user presets.
struct PresetChipsView: View {
    let viewModel: EqualizerViewModel
    @Binding var edit: PresetEdit?
    /// Wrapped grid in landscape, a single scrolling row in portrait.
    let isWrapped: Bool

    var body: some View {
        if isWrapped {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: Spacing.s)], alignment: .leading, spacing: Spacing.s) {
                chips
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) { chips }
                    .padding(.horizontal, Spacing.screenMargin)
            }
            .padding(.horizontal, -Spacing.screenMargin)
        }
    }

    @ViewBuilder
    private var chips: some View {
        if viewModel.isCustom {
            Chip(title: String(localized: "Custom", bundle: .module), isSelected: true) {}
        }
        ForEach(viewModel.presets) { preset in
            Chip(title: Strings.name(of: preset), isSelected: viewModel.selectedPreset?.id == preset.id) {
                viewModel.select(preset)
            }
            .contextMenu {
                if !preset.isBuiltIn {
                    Button(String(localized: "Rename", bundle: .module), systemImage: "pencil") { edit = .rename(preset) }
                    Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) { edit = .delete(preset) }
                }
            }
        }
        Chip(title: String(localized: "Save As…", bundle: .module), systemImage: "plus", isSelected: false) {
            edit = .save
        }
    }
}

private struct Chip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage).imageScale(.small)
                }
                Text(title).lineLimit(1)
            }
            .font(AppFont.body)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
