import Domain
import SwiftUI

/// The Folders tab root: owns the navigation path and the live store.
struct FoldersRootView: View {
    let context: FoldersContext

    @State private var path: [FoldersRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            FolderBrowserView(folderID: nil, context: context)
                .navigationDestination(for: FoldersRoute.self) { route in
                    switch route {
                    case let .folder(id):
                        FolderBrowserView(folderID: id, context: context)
                    }
                }
        }
        .task {
            await context.store.observe()
        }
    }
}
