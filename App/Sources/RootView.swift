import BrowserFeature
import DesignSystem
import Domain
import EqualizerFeature
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
                LibraryFeature.makeRootView(dependencies: container) {
                    router.isSettingsPresented = true
                }
                .miniPlayerContentInset()
            }
            Tab("Folders", systemImage: "folder", value: AppRouter.Tab.folders) {
                FoldersFeature.makeRootView(dependencies: container)
                    .miniPlayerContentInset()
            }
            if container.flags.isBrowserEnabled {
                Tab("Browser", systemImage: "globe", value: AppRouter.Tab.browser) {
                    NavigationStack { BrowserPlaceholderView().navigationTitle("Browser") }
                        .miniPlayerContentInset()
                }
            }
        }
        .modifier(PlayerFeature.host(dependencies: container) {
            EqualizerFeature.makeSheet(dependencies: container)
        })
        .sheet(isPresented: $router.isSettingsPresented) {
            NavigationStack {
                EqualizerFeature.makePresetManager(dependencies: container)
            }
        }
        .tint(AccentPalette.option(id: container.settings.accentColorID).color)
        .background(WindowInterfaceStyle(style: container.settings.theme.interfaceStyle))
        .task { await container.observeSettings() }
    }
}

private extension AppTheme {
    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Applies the theme to the whole window, so sheets, alerts and the full-screen player follow it too
/// (`.preferredColorScheme` only reaches the current presentation).
private struct WindowInterfaceStyle: UIViewRepresentable {
    let style: UIUserInterfaceStyle

    func makeUIView(context _: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: ProbeView, context _: Context) {
        view.style = style
    }

    final class ProbeView: UIView {
        var style: UIUserInterfaceStyle = .unspecified {
            didSet { window?.overrideUserInterfaceStyle = style }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            window?.overrideUserInterfaceStyle = style
        }
    }
}
