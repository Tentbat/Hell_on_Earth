import SwiftUI
import EarthFromAboveCore

/// The in-flight screen: takeoff button, position and confidence, what is
/// visible now, and what is next.
struct LiveWindowView: View {
    @Environment(AppState.self) private var app
    @State private var confirmEnd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let b = app.bundle {
                    header(b)
                    takeoffControl
                    if let est = app.estimate {
                        stats(est, bundle: b)
                        nowAndNext(est, bundle: b)
                    } else {
                        Text("Tap the button at takeoff. The app will also try to detect takeoff from cabin pressure and GPS.")
                            .font(.callout).foregroundStyle(.secondary)
                        preflightBriefing(b)
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("End flight", role: .destructive) { confirmEnd = true }
            }
        }
        .confirmationDialog("End this flight and clear the guide?", isPresented: $confirmEnd) {
            Button("End flight", role: .destructive) { app.endFlight() }
        }
    }

    @ViewBuilder private func header(_ b: RouteBundle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(b.flight.airline ?? "") \(b.flight.flightNumber)").font(.headline)
            Text("\(b.flight.originName) to \(b.flight.destinationName)").foregroundStyle(.secondary)
            HStack {
                if let a = b.aircraft { NavigationLink(a.typeName) { AircraftView(aircraft: a) }.font(.footnote) }
                Spacer()
                SideBadge(side: app.userSide)
            }
        }
    }

    @ViewBuilder private var takeoffControl: some View {
        if app.takeoffTime == nil {
            Button {
                app.markTakeoff()
            } label: {
                Label("We're off! Tap at takeoff", systemImage: "airplane.departure")
                    .font(.title2.weight(.bold)).frame(maxWidth: .infinity).padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
        } else {
            HStack {
                Label("Took off \(app.takeoffTime!, style: .time)", systemImage: "airplane.departure")
                Spacer()
                Button("Undo") { app.undoTakeoff() }.font(.footnote)
            }
            .font(.callout)
        }
    }

    @ViewBuilder private func stats(_ est: PositionEstimate, bundle b: RouteBundle) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            StatTile(title: "Elapsed", value: UnitFormat.clock(est.elapsedSeconds))
            StatTile(title: "Remaining", value: app.remainingSeconds.map { UnitFormat.duration($0) } ?? "–")
            StatTile(title: "Phase", value: app.phase.displayName)
            StatTile(title: "Altitude", value: UnitFormat.feet(fromMeters: est.altitudeMeters))
            StatTile(title: "Ground speed", value: UnitFormat.mph(fromMetersPerSecond: est.groundSpeedMetersPerSecond))
            StatTile(title: "Position from", value: est.source.displayName)
        }
        HStack(spacing: 6) {
            Circle().fill(est.confidence == .high ? .green : est.confidence == .medium ? .orange : .red).frame(width: 8, height: 8)
            Text(confidenceText(est)).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func confidenceText(_ est: PositionEstimate) -> String {
        switch est.confidence {
        case .high: return "Position known to within about \(UnitFormat.miles(fromMeters: est.uncertaintyMeters))."
        case .medium: return "Position roughly known (about \(UnitFormat.miles(fromMeters: est.uncertaintyMeters))). Hold the phone near the window for GPS."
        case .low: return "Estimated from the schedule only (about \(UnitFormat.miles(fromMeters: est.uncertaintyMeters))). Hold the phone near the window for a GPS fix."
        }
    }

    @ViewBuilder private func nowAndNext(_ est: PositionEstimate, bundle b: RouteBundle) -> some View {
        if let planner = app.planner {
            let now = planner.visibleNow(elapsed: est.elapsedSeconds, userSide: app.userSide)
            let next = planner.upcoming(fromElapsed: est.elapsedSeconds + 90, horizonSeconds: 2_400, userSide: app.userSide)
            let vis = planner.visibility.visibility(atElapsed: est.elapsedSeconds)

            VisibilityBadge(visibility: vis)

            if !now.isEmpty {
                Text("Out your window now").font(.headline)
                ForEach(now) { item in LookoutRow(item: item, elapsedNow: est.elapsedSeconds) }
            }
            Text("Coming up").font(.headline)
            if next.isEmpty {
                Text("Nothing on your side in the next 40 minutes. Check the Look out tab for the whole flight.").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(next.prefix(8)) { item in LookoutRow(item: item, elapsedNow: est.elapsedSeconds) }
            }
        }
    }

    @ViewBuilder private func preflightBriefing(_ b: RouteBundle) -> some View {
        if let planner = app.planner {
            let highlights = planner.highlights(count: 8, userSide: app.userSide)
            Text("Highlights of this flight").font(.headline)
            ForEach(highlights) { item in LookoutRow(item: item, elapsedNow: nil) }
            if !b.notes.isEmpty {
                DisclosureGroup("About this guide") {
                    ForEach(b.notes, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                }
            }
        }
    }
}

struct LookoutRow: View {
    @Environment(AppState.self) private var app
    var item: LookoutItem
    var elapsedNow: Double?

    var body: some View {
        NavigationLink {
            if case .feature(let f) = item.kind { FeatureDetailView(feature: f, kidBand: nil) }
            else { CrossingDetailView(item: item) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                CategoryIcon(category: item.category).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.body.weight(.medium))
                    Text(item.summary).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                    HStack(spacing: 8) {
                        SideBadge(side: item.side)
                        if item.visibility != .unknown { VisibilityBadge(visibility: item.visibility) }
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    if let now = elapsedNow {
                        let dt = item.elapsedSeconds - now
                        Text(dt > 60 ? "in \(Int(dt / 60)) min" : dt < -60 ? "\(Int(-dt / 60)) min ago" : "now")
                            .font(.callout.weight(.semibold)).monospacedDigit()
                    } else {
                        Text("+\(Int(item.elapsedSeconds / 60)) min").font(.callout).monospacedDigit()
                    }
                    if item.lateralDistanceMeters > 0 {
                        Text(UnitFormat.miles(fromMeters: item.lateralDistanceMeters)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct CrossingDetailView: View {
    var item: LookoutItem
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.summary)
                if let k = item.kidSummary { Text(k).font(.callout).foregroundStyle(.secondary) }
            }.padding()
        }
        .navigationTitle(item.name)
    }
}
