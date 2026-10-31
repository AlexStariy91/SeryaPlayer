import DesignSystem
import SwiftUI

/// The `AccentPalette` options as color swatches.
struct AccentPicker: View {
    let selectedID: String
    let onSelect: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accent Color", bundle: .module)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AccentPalette.all) { option in
                    swatch(option)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func swatch(_ option: AccentOption) -> some View {
        let isSelected = option.id == AccentPalette.option(id: selectedID).id
        return Button {
            onSelect(option.id)
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(2)
                .overlay {
                    Circle().strokeBorder(isSelected ? option.color : .clear, lineWidth: 2)
                }
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.localizedName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
