import SwiftUI

@main
struct EarthFromAboveApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task { await appState.start() }
        }
    }
}
