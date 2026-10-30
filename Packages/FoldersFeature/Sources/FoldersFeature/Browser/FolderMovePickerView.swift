import DesignSystem
import Domain
import SwiftUI

/// "Move to Folder": the folder tree (without the moved folders) plus the library root.
struct FolderMovePickerView: View {
    let items: Set<FolderItem>
    let viewModel: FolderBrowserViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row(name: String(localized: "Library Root", bundle: .module), systemImage: "tray", depth: 0, destination: nil)
                ForEach(viewModel.destinations(for: items)) { item in
                    row(name: item.folder.name, systemImage: "folder", depth: item.depth, destination: item.folder.id)
                }
            }
            .navigationTitle(Text("Move to Folder", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(name: String, systemImage: String, depth: Int, destination: Folder.ID?) -> some View {
        Button {
            Task {
                await viewModel.move(items, to: destination)
                dismiss()
            }
        } label: {
            HStack {
                Label(name, systemImage: systemImage)
                    .foregroundStyle(SemanticColor.textPrimary)
                Spacer()
                if viewModel.isCurrent(destination, for: items) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel(Text("Current folder", bundle: .module))
                }
            }
            .padding(.leading, CGFloat(depth) * Spacing.l)
        }
    }
}
