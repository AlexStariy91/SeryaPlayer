import Domain

/// A row of a folder screen, used as the multi-selection element.
enum FolderItem: Hashable {
    case folder(Folder.ID)
    case track(Track.ID)
}

/// Destinations pushed onto the Folders `NavigationStack`.
enum FoldersRoute: Hashable {
    case folder(Folder.ID)
}

/// A folder with its depth in the tree, in display order (siblings by `sortIndex`, then name).
struct FolderTreeRow: Identifiable, Equatable {
    let folder: Folder
    let depth: Int

    var id: Folder.ID {
        folder.id
    }

    static func flatten(_ folders: [Folder], excluding excluded: Set<Folder.ID> = []) -> [FolderTreeRow] {
        let children = Dictionary(grouping: folders, by: \.parentID)
        var result: [FolderTreeRow] = []
        func visit(_ parent: Folder.ID?, depth: Int) {
            let siblings = (children[parent] ?? []).sorted { ($0.sortIndex, $0.name) < ($1.sortIndex, $1.name) }
            for folder in siblings where !excluded.contains(folder.id) {
                result.append(FolderTreeRow(folder: folder, depth: depth))
                visit(folder.id, depth: depth + 1)
            }
        }
        visit(nil, depth: 0)
        return result
    }
}
