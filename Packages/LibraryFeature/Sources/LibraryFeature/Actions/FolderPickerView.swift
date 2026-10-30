import DesignSystem
import Domain
import SwiftUI

/// "Move to Folder…": a flat, indented view of the folder tree plus the library root.
struct FolderPickerView: View {
    let tracks: [Track]
    let folders: any FolderRepository
    let actions: TrackActionsModel

    @Environment(\.dismiss) private var dismiss
    @State private var rows: [FolderTreeRow] = []

    var body: some View {
        NavigationStack {
            List {
                row(name: String(localized: "Library Root", bundle: .module), systemImage: "tray", depth: 0, folderID: nil)
                ForEach(rows) { item in
                    row(name: item.folder.name, systemImage: "folder", depth: item.depth, folderID: item.folder.id)
                }
            }
            .navigationTitle(Text("Move to Folder", bundle: .module))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", bundle: .module)) { dismiss() }
                }
            }
            .task {
                for await list in folders.observeFolders() {
                    rows = FolderTreeRow.flatten(list)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(name: String, systemImage: String, depth: Int, folderID: Folder.ID?) -> some View {
        let isCurrent = !tracks.isEmpty && tracks.allSatisfy { $0.folderID == folderID }
        return Button {
            Task {
                await actions.move(tracks, toFolder: folderID)
                dismiss()
            }
        } label: {
            HStack {
                Label(name, systemImage: systemImage)
                    .foregroundStyle(SemanticColor.textPrimary)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel(Text("Current folder", bundle: .module))
                }
            }
            .padding(.leading, CGFloat(depth) * Spacing.l)
        }
    }
}

/// A folder with its depth in the tree, in display order (siblings by `sortIndex`, then name).
struct FolderTreeRow: Identifiable, Equatable {
    let folder: Folder
    let depth: Int

    var id: Folder.ID {
        folder.id
    }

    static func flatten(_ folders: [Folder]) -> [FolderTreeRow] {
        let children = Dictionary(grouping: folders, by: \.parentID)
        var result: [FolderTreeRow] = []
        func visit(_ parent: Folder.ID?, depth: Int) {
            let siblings = (children[parent] ?? []).sorted {
                ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name)
            }
            for folder in siblings {
                result.append(FolderTreeRow(folder: folder, depth: depth))
                visit(folder.id, depth: depth + 1)
            }
        }
        visit(nil, depth: 0)
        return result
    }
}
