import SwiftUI
import EarthFromAboveCore

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var backend = ""

    var body: some View {
        @Bindable var app = app
        Form {
            Section("Kid mode") {
                Toggle("Kid mode", isOn: $app.settings.kidModeEnabled)
                Picker("Age band", selection: $app.settings.kidBand) {
                    ForEach(KidBand.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Allow online explanations in kid mode", isOn: $app.settings.kidOnlineExplanationsAllowed)
                Text("Explorer is for about 5 to 8 with a parent holding the phone. Navigator is for about 9 to 13 on their own. Online explanations send the photo to our server; leave this off if you would rather it stayed on the phone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Notifications") {
                Toggle("Notify me of upcoming sights", isOn: $app.settings.notificationsEnabled)
                Picker("Lead time", selection: $app.settings.notificationLeadSeconds) {
                    Text("2 minutes").tag(120.0); Text("5 minutes").tag(300.0); Text("10 minutes").tag(600.0)
                }
                Button("Allow background location") { app.location.requestAlwaysAuthorization() }
                Text("Background location keeps the flight tracked with the phone locked, so notifications stay accurate.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Plan") {
                Toggle("Premium (developer switch)", isOn: $app.settings.isPremium)
                Text("Free: one flight guide at a time, the look-out list, offline photo matching and \(APIClient.freeExplanationsPerFlight) online explanations per flight. Premium and the per-flight pass unlock unlimited explanations, weather and ride outlook, alerts and more. Purchases will go through the App Store; this switch is for development.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Server") {
                TextField("Backend URL", text: $backend).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onSubmit { app.settings.backendURL = backend; app.api = APIClient(baseURL: APIClient.resolveBaseURL(override: backend)) }
                Text("Leave blank for the default. Set to your Mac's address while developing, e.g. http://192.168.1.20:8000").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Sensors") {
                LabeledContent("Barometer", value: app.motion.isBarometerAvailable ? "Available" : "Not available")
                LabeledContent("Location", value: locationText)
            }
        }
        .navigationTitle("Settings")
        .onAppear { backend = app.settings.backendURL }
        .onChange(of: app.settings.notificationsEnabled) { _, _ in app.scheduleNotifications() }
        .onChange(of: app.settings.notificationLeadSeconds) { _, _ in app.scheduleNotifications() }
    }

    private var locationText: String {
        switch app.location.authorization {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While using"
        case .denied, .restricted: return "Denied. Enable in Settings."
        default: return "Not asked yet"
        }
    }
}
