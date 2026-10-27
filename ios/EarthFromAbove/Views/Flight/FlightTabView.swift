import SwiftUI
import EarthFromAboveCore

/// Setup before the flight and the live window once a bundle is loaded.
struct FlightTabView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationStack {
            Group {
                if app.bundle != nil { LiveWindowView() } else { FlightSetupView() }
            }
            .navigationTitle(app.bundle.map { "\($0.flight.originCode) to \($0.flight.destinationCode)" } ?? "Earth from Above")
            .toolbar {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
            }
        }
    }
}

struct FlightSetupView: View {
    @Environment(AppState.self) private var app
    @State private var flightNumber = ""
    @State private var date = Date()
    @State private var seat = ""
    @State private var side: CabinSide? = nil
    @State private var showInterests = false

    var body: some View {
        Form {
            Section("Your flight") {
                TextField("Flight number, e.g. AS 123", text: $flightNumber)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            Section("Your seat") {
                TextField("Seat, e.g. 14A", text: $seat)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .onChange(of: seat) { _, new in
                        app.settings.seat = new
                        if let s = CabinSide.fromSeat(new) { side = s; app.settings.side = s }
                    }
                Picker("Window side", selection: $side) {
                    Text("Not sure").tag(CabinSide?.none)
                    Text("Left (A seats)").tag(CabinSide?.some(.left))
                    Text("Right (F or K seats)").tag(CabinSide?.some(.right))
                }
                .onChange(of: side) { _, new in app.settings.side = new }
                Text("Seat A is on the left of every airliner. The highest letter in the row is on the right.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("What are you keen to see?") {
                NavigationLink {
                    InterestChecklistView()
                } label: {
                    HStack {
                        Text("Interests")
                        Spacer()
                        Text(app.settings.interests.selected.isEmpty ? "Everything" : "\(app.settings.interests.selected.count) chosen")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button {
                    Task { await app.downloadBundle(flightNumber: flightNumber.replacingOccurrences(of: " ", with: ""), date: date) }
                } label: {
                    HStack {
                        if app.isDownloading { ProgressView().padding(.trailing, 6) }
                        Text("Download flight guide")
                    }
                }
                .disabled(flightNumber.trimmingCharacters(in: .whitespaces).isEmpty || app.isDownloading)
                Button("Load sample flight (Seattle to Denver)") { app.loadSampleBundle() }
                if let e = app.lastError { Text(e).font(.footnote).foregroundStyle(.red) }
            } footer: {
                Text("Download on the ground while you have Wi-Fi. The guide holds the predicted route, terrain, sights, borders and weather so everything works in the air with no connection.")
            }
            if !app.store.list().isEmpty {
                Section("Saved flight guides") {
                    ForEach(app.store.list(), id: \.generatedAt) { b in
                        Button {
                            app.apply(bundle: b, takeoff: nil)
                        } label: {
                            VStack(alignment: .leading) {
                                Text("\(b.flight.flightNumber): \(b.flight.originName) to \(b.flight.destinationName)")
                                Text(b.generatedAt, style: .date).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { seat = app.settings.seat; side = app.settings.side }
    }
}

struct InterestChecklistView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        List {
            Section {
                Text("Leave everything unchecked to see it all. Check boxes to focus the look-out list and notifications.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(InterestGroup.allCases) { group in
                Section {
                    ForEach(group.categories) { cat in
                        Button {
                            app.settings.interests.toggle(cat)
                        } label: {
                            HStack {
                                Image(systemName: app.settings.interests.selected.contains(cat) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(app.settings.interests.selected.contains(cat) ? Color.accentColor : .secondary)
                                Text(cat.displayName).foregroundStyle(.primary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(group.displayName)
                        Spacer()
                        Button("All") { app.settings.interests.toggle(group: group) }.font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Interests")
    }
}
