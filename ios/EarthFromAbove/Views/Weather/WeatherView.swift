import SwiftUI
import EarthFromAboveCore

struct WeatherView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if let b = app.bundle, let planner = app.planner {
            List {
                Section("Will I see the ground?") {
                    VisibilityStrip(model: planner.visibility, total: b.route.totalDurationSeconds, elapsed: app.elapsedSeconds)
                    ForEach(Array(planner.visibility.windows(totalDurationSeconds: b.route.totalDurationSeconds).enumerated()), id: \.offset) { _, w in
                        HStack {
                            VisibilityBadge(visibility: w.visibility)
                            Spacer()
                            Text("+\(Int(w.start / 60)) to +\(Int(w.end / 60)) min").font(.caption).monospacedDigit()
                        }
                    }
                    if b.clouds.isEmpty { Text("No cloud data in this guide. Refresh the guide with a connection to add satellite cloud cover.").font(.footnote).foregroundStyle(.secondary) }
                }
                Section("Ride and seatbelt sign") {
                    if b.turbulence.isEmpty {
                        Text("No turbulence outlook in this guide.").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(b.turbulence.enumerated()), id: \.offset) { _, t in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("+\(Int(t.elapsedSeconds / 60)) min").monospacedDigit()
                                    Text(t.level.displayName).fontWeight(.semibold)
                                    if t.level.seatbeltLikely { Label("Seatbelt sign likely", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
                                }
                                Text(t.cause.explanation).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("Forecasts come from turbulence guidance grids and pilot reports. Pilots see the same data and route around the worst of it, so the outlook is a ceiling, not a prediction.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Weather and ride")
        } else {
            EmptyFlightView()
        }
    }
}
