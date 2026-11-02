import Domain
import SwiftUI

/// The Folders tab root: owns the navigation path and the live store.
struct FoldersRootView: View {
    /// Held in `@State` so a parent re-render (e.g. switching tabs) doesn't rebuild the store.
    @State private var context: FoldersContext

    @State private var path: [FoldersRoute] = []

    init(context: FoldersContext) {
        _context = State(wrappedValue: context)
    }

    var body: some View {
        NavigationStack(path: $path) {
            FolderBrowserView(folderID: nil, context: context)
                .navigationDestination(for: FoldersRoute.self) { route in
                    switch route {
                    case let .folder(id):
                        FolderBrowserView(folderID: id, context: context)
                            // Back arrow only, in every mode: the label otherwise jumps between "Folders", "Back" and nothing in Select.
                            .toolbarRole(.editor)
                    }
                }
        }
        .task {
            await context.store.observe()
        }
    }
}
