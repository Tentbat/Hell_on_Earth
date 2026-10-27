import SwiftUI
import EarthFromAboveCore

/// "What is that?" Shoot or import a photo, get offline candidates from geometry,
/// and optionally an online explanation.
struct PhotoIDView: View {
    @Environment(AppState.self) private var app
    @State private var pickerSource: ImagePicker.Source?
    @State private var image: UIImage?
    @State private var pose: CameraPose?
    @State private var candidates: [PhotoCandidate] = []
    @State private var footprint: GroundFootprint?
    @State private var explanation: APIClient.ExplainResponse?
    @State private var isExplaining = false
    @State private var error: String?
    @State private var question = ""
    @State private var sharing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if app.bundle == nil {
                        EmptyFlightView()
                    } else {
                        captureButtons
                        if let image {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 280).clipShape(RoundedRectangle(cornerRadius: 12))
                            poseSummary
                            candidateList
                            onlineSection
                        } else {
                            Text("Point the camera out of the window and shoot. The app works out which patch of ground is in the frame from the plane's position, your side of the plane and the phone's tilt, then lists what is there. With a connection it can explain the scene in detail.")
                                .font(.callout).foregroundStyle(.secondary)
                            if app.userSide == nil {
                                Label("Set your window side on the Flight tab first for accurate results.", systemImage: "exclamationmark.triangle")
                                    .font(.footnote).foregroundStyle(.orange)
                            }
                        }
                        if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                    }
                }
                .padding()
            }
            .navigationTitle("What is that?")
            .sheet(item: $pickerSource) { source in
                ImagePicker(source: source) { img, taken in handle(image: img, takenAt: taken, fromCamera: source == .camera) }
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $sharing) {
                if let image, let est = app.estimate, let b = app.bundle {
                    ShareSightingView(image: image, estimate: est, flightNumber: b.flight.flightNumber,
                                      feature: candidates.first?.feature, suggestedTitle: explanation?.title ?? candidates.first?.feature.name ?? "Spotted from the air")
                }
            }
        }
    }

    private var captureButtons: some View {
        HStack {
            Button { pickerSource = .camera } label: { Label("Shoot", systemImage: "camera").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent)
            Button { pickerSource = .library } label: { Label("Import", systemImage: "photo").frame(maxWidth: .infinity) }
                .buttonStyle(.bordered)
        }
    }

    @ViewBuilder private var poseSummary: some View {
        if let pose, let fp = footprint {
            VStack(alignment: .leading, spacing: 4) {
                Text("Looking \(pose.side == .left ? "left" : "right"), \(Int(pose.depressionDegrees))° below the horizon, from \(UnitFormat.feet(fromMeters: pose.heightAboveGroundMeters)) up.")
                Text(fp.includesHorizon
                     ? "The frame reaches the horizon, about \(UnitFormat.miles(fromMeters: fp.centerDistanceMeters)) to the centre of the view."
                     : "Centre of the frame is about \(UnitFormat.miles(fromMeters: fp.centerDistanceMeters)) away.")
            }
            .font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var candidateList: some View {
        Text(candidates.isEmpty ? "Nothing named in the guide is in this patch of ground." : "Probably in this photo").font(.headline)
        if candidates.isEmpty {
            Text("Try the online explanation, which can describe landforms, clouds and patterns that are not in the database.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        ForEach(candidates) { c in
            NavigationLink {
                FeatureDetailView(feature: c.feature, kidBand: app.settings.kidModeEnabled ? app.settings.kidBand : nil)
            } label: {
                HStack {
                    CategoryIcon(category: c.feature.category).foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(c.feature.name).font(.body.weight(.medium))
                        Text("\(UnitFormat.miles(fromMeters: c.distanceMeters)) away, match \(Int(c.score * 100))%")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var onlineSection: some View {
        Divider()
        Text("Explain this view").font(.headline)
        if let e = explanation {
            VStack(alignment: .leading, spacing: 8) {
                Text(e.title).font(.title3.weight(.semibold))
                Text(e.explanation)
                if !e.followUps.isEmpty {
                    Text("Ask more").font(.caption).foregroundStyle(.secondary)
                    ForEach(e.followUps, id: \.self) { q in
                        Button(q) { question = q; Task { await explain() } }.font(.callout)
                    }
                }
                Text("Confidence: \(e.confidence)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.08)))
        }
        let kidBlocked = app.settings.kidModeEnabled && !app.settings.kidOnlineExplanationsAllowed
        if kidBlocked {
            Text("Online explanations are turned off in kid mode. A parent can enable them in Settings.").font(.footnote).foregroundStyle(.secondary)
        } else {
            TextField("Optional question, e.g. why are the fields circular?", text: $question, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await explain() }
            } label: {
                HStack {
                    if isExplaining { ProgressView().padding(.trailing, 4) }
                    Text(app.canExplainOnline ? "Explain (needs a connection)" : "Explain (free limit reached)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isExplaining || !app.canExplainOnline)
            if !app.settings.isPremium {
                Text("\(max(0, APIClient.freeExplanationsPerFlight - app.settings.onlineExplanationsUsedThisFlight)) free explanations left on this flight.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        Button { sharing = true } label: { Label("Share with family and friends", systemImage: "person.2") }
            .font(.callout).disabled(app.settings.kidModeEnabled)
    }

    private func handle(image img: UIImage, takenAt: Date?, fromCamera: Bool) {
        image = img
        explanation = nil
        error = nil
        guard let b = app.bundle else { return }
        // Position at the time of the shot. For imported photos, place by timestamp on the schedule.
        var est = app.estimate
        if !fromCamera, let taken = takenAt, let t0 = app.takeoffTime {
            let s = b.route.sample(atElapsed: taken.timeIntervalSince(t0))
            est = PositionEstimate(coordinate: s.coordinate, altitudeMeters: s.altitudeMeters, trackDegrees: s.trackDegrees,
                                   groundSpeedMetersPerSecond: s.groundSpeedMetersPerSecond, elapsedSeconds: taken.timeIntervalSince(t0),
                                   source: .deadReckoning, uncertaintyMeters: 20_000, time: taken)
        }
        guard let est else { error = "No position yet. Tap the takeoff button or wait for GPS."; return }
        let side = app.userSide ?? .left
        // Height above ground: altitude minus a rough terrain height from the nearest feature elevations, else sea level.
        let nearbyElev = FeatureIndex(features: b.features).nearby(est.coordinate, radiusMeters: 50_000).compactMap { $0.feature.elevationMeters }.first ?? 0
        let depression = fromCamera ? app.motion.cameraDepressionDegrees() : 15
        let p = CameraPose(position: est.coordinate, heightAboveGroundMeters: max(300, est.altitudeMeters - nearbyElev),
                           trackDegrees: est.trackDegrees, side: side, depressionDegrees: depression,
                           horizontalFOVDegrees: fromCamera ? 69 : 80, verticalFOVDegrees: fromCamera ? 54 : 70)
        pose = p
        footprint = CameraGeometry.footprint(for: p)
        candidates = CameraGeometry.candidates(for: p, in: FeatureIndex(features: b.features))
    }

    private func explain() async {
        guard let image, let pose, let b = app.bundle, app.canExplainOnline else { return }
        isExplaining = true
        defer { isExplaining = false }
        do {
            let r = try await app.api.explain(image: image, pose: pose, elapsedSeconds: app.elapsedSeconds, flightNumber: b.flight.flightNumber,
                                              candidates: candidates, kidBand: app.settings.kidModeEnabled ? app.settings.kidBand : nil,
                                              question: question.isEmpty ? nil : question)
            explanation = r
            if !app.settings.isPremium { app.settings.onlineExplanationsUsedThisFlight += 1 }
            error = nil
        } catch {
            self.error = "Could not reach the server. Offline candidates above still apply. (\(error.localizedDescription))"
        }
    }
}

extension ImagePicker.Source: Identifiable {
    var id: String { self == .camera ? "camera" : "library" }
}

struct ShareSightingView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    var image: UIImage
    var estimate: PositionEstimate
    var flightNumber: String
    var feature: Feature?
    var suggestedTitle: String
    @State private var title = ""
    @State private var note = ""
    @State private var circle = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your circle") {
                    TextField("Family code, e.g. WEINSTEIN-7F2K", text: $circle).textInputAutocapitalization(.characters)
                    Text("Sightings are shared only with people who have the same code. Make one up and share it by text.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Sighting") {
                    TextField("Title", text: $title)
                    TextField("Note", text: $note, axis: .vertical)
                }
                Section {
                    Button(busy ? "Posting..." : "Post") { Task { await post() } }.disabled(busy || circle.isEmpty || title.isEmpty)
                    if let m = message { Text(m).font(.footnote) }
                }
            }
            .navigationTitle("Share sighting")
            .toolbar { Button("Done") { dismiss() } }
            .onAppear { title = suggestedTitle; circle = UserDefaults.standard.string(forKey: "efa.circle") ?? "" }
        }
    }

    private func post() async {
        busy = true; defer { busy = false }
        UserDefaults.standard.set(circle, forKey: "efa.circle")
        do {
            _ = try await app.api.postSighting(circleCode: circle, title: title, note: note.isEmpty ? nil : note, feature: feature,
                                               estimate: estimate, flightNumber: flightNumber, image: image)
            message = "Posted. It will appear for your circle when they next have a connection."
        } catch { message = "Could not post now: \(error.localizedDescription). Try again when you have Wi-Fi." }
    }
}
