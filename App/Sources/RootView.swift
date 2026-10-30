import BrowserFeature
import DesignSystem
import FoldersFeature
import LibraryFeature
import PlayerFeature
import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            Tab("Library", systemImage: "music.note.list", value: AppRouter.Tab.library) {
                NavigationStack { LibraryPlaceholderView().navigationTitle("Library") }
            }
            Tab("Folders", systemImage: "folder", value: AppRouter.Tab.folders) {
                NavigationStack { FoldersPlaceholderView().navigationTitle("Folders") }
            }
            if container.flags.isBrowserEnabled {
                Tab("Browser", systemImage: "globe", value: AppRouter.Tab.browser) {
                    NavigationStack { BrowserPlaceholderView().navigationTitle("Browser") }
                }
            }
        }
        .tint(AccentPalette.serya.color)
    }
}
