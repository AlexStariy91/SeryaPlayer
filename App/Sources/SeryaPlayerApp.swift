import SwiftUI

@main
struct SeryaPlayerApp: App {
    @State private var container = AppContainer.make(arguments: ProcessInfo.processInfo.arguments)

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
