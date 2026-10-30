import SwiftUI

@main
struct SeryaPlayerApp: App {
    @State private var startup = Result { try AppContainer(environment: .current()) }
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            switch startup {
            case let .success(container):
                RootView(container: container)
                    .task { await container.didLaunch() }
                    .onOpenURL { url in
                        Task { await container.open(url) }
                    }
                    .onChange(of: scenePhase) { _, phase in
                        switch phase {
                        case .active: Task { await container.didBecomeActive() }
                        case .background: Task { await container.didEnterBackground() }
                        default: break
                        }
                    }
            case let .failure(error):
                StartupErrorView(error: error)
            }
        }
    }
}

/// Shown only if the database can't be opened, instead of crashing on launch.
private struct StartupErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView(
            "Can't Open the Library",
            systemImage: "exclamationmark.triangle",
            description: Text(error.localizedDescription)
        )
    }
}
