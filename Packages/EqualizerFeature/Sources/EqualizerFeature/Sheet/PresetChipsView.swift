import DesignSystem
import Domain
import SwiftUI

/// Preset chips wrapped into rows: "Custom" first when the curve matches nothing, then built-in and user presets.
/// A "Save As…" row closes the card.
struct PresetChipsView: View {
    let viewModel: EqualizerViewModel
    @Binding var edit: PresetEdit?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FlowLayout(spacing: Spacing.s) { chips }
                .padding(Spacing.m)
            Divider()
                .padding(.leading, Spacing.l)
            Button {
                edit = .save
            } label: {
                Label {
                    Text("Save As…", bundle: .module)
                } icon: {
                    Image(systemName: "plus.circle.fill")
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, Spacing.l)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("equalizer.saveAs")
        }
    }

    @ViewBuilder
    private var chips: some View {
        // Matched once per render, not once per chip: this view redraws on every frame of a curve drag.
        let selectedID = viewModel.selectedPreset?.id
        if selectedID == nil {
            Chip(title: String(localized: "Custom", bundle: .module), isSelected: true) {}
        }
        ForEach(viewModel.presets) { preset in
            Chip(title: Strings.name(of: preset), isSelected: selectedID == preset.id) {
                viewModel.select(preset)
            }
            .contextMenu {
                if !preset.isBuiltIn {
                    Button(String(localized: "Rename", bundle: .module), systemImage: "pencil") { edit = .rename(preset) }
                    Button(String(localized: "Delete", bundle: .module), systemImage: "trash", role: .destructive) { edit = .delete(preset) }
                }
            }
        }
    }
}

private struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .font(AppFont.rowSubtitle.weight(isSelected ? .semibold : .regular))
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, 7)
                // Background color on the accent: white on the dark light-mode accent, black on the pale dark-mode one.
                .foregroundStyle(isSelected ? SemanticColor.background : SemanticColor.textPrimary)
                .background(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemFill), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Places subviews left to right and wraps to a new row when the next one doesn't fit.
/// A subview wider than the row is offered the row's width (a chip then truncates).
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = arrange(subviews, in: proposal.width)
        // Fills a finite proposed width so the rows stay leading-aligned in the card.
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? result.size.width
        return CGSize(width: width, height: result.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = arrange(subviews, in: bounds.width)
        for (subview, frame) in zip(subviews, result.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(_ subviews: Subviews, in proposedWidth: CGFloat?) -> (frames: [CGRect], size: CGSize) {
        // `nil`, infinite or not-a-number widths (an unsized container during presentation) mean "one row".
        let maxWidth = proposedWidth.flatMap { $0.isFinite ? max($0, 0) : nil } ?? .greatestFiniteMagnitude
        var frames: [CGRect] = []
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                size.width = min(size.width, maxWidth)
            }
            if origin.x > 0, origin.x + size.width > maxWidth {
                origin.x = 0
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: origin, size: size))
            usedWidth = max(usedWidth, origin.x + size.width)
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (frames, CGSize(width: usedWidth, height: frames.isEmpty ? 0 : origin.y + rowHeight))
    }
}
