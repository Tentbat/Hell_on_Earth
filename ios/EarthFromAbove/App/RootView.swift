import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if app.settings.kidModeEnabled {
            KidRootView()
        } else {
            TabView {
                FlightTabView()
                    .tabItem { Label("Flight", systemImage: "airplane") }
                LookoutListView()
                    .tabItem { Label("Look out", systemImage: "binoculars") }
                FlightMapView()
                    .tabItem { Label("Map", systemImage: "map") }
                PhotoIDView()
                    .tabItem { Label("What is that?", systemImage: "camera.viewfinder") }
                LearnView()
                    .tabItem { Label("Learn", systemImage: "book") }
            }
        }
    }
}
