import SwiftUI
import EarthFromAboveCore

struct LookoutListView: View {
    @Environment(AppState.self) private var app
    @State private var onlyMySide = true
    @State private var hideClouded = false

    var body: some View {
        NavigationStack {
            Group {
                if let planner = app.planner, let b = app.bundle {
                    let items = planner.timeline(userSide: onlyMySide ? app.userSide : nil)
                        .filter { !hideClouded || $0.visibility != .obscured }
                    List {
                        Section {
                            Toggle("Only my side of the plane", isOn: $onlyMySide).disabled(app.userSide == nil)
                            Toggle("Hide things under cloud", isOn: $hideClouded)
                        }
                        Section("Visibility along the route") {
                            VisibilityStrip(model: planner.visibility, total: b.route.totalDurationSeconds, elapsed: app.elapsedSeconds)
                        }
                        Section("\(items.count) things to look out for") {
                            ForEach(items) { item in
                                LookoutRow(item: item, elapsedNow: app.takeoffTime == nil ? nil : app.elapsedSeconds)
                            }
                        }
                    }
                } else {
                    EmptyFlightView()
                }
            }
            .navigationTitle("Look out for")
        }
    }
}

struct VisibilityStrip: View {
    var model: VisibilityModel
    var total: Double
    var elapsed: Double

    var body: some View {
        let windows = model.windows(totalDurationSeconds: total)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(Array(windows.enumerated()), id: \.offset) { _, w in
                        Rectangle().fill(color(w.visibility))
                            .frame(width: max(0, geo.size.width * (w.end - w.start) / max(1, total)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                if elapsed > 0 {
                    Rectangle().fill(.primary).frame(width: 2)
                        .offset(x: geo.size.width * min(1, elapsed / max(1, total)))
                }
            }
        }
        .frame(height: 14)
        HStack {
            Text("Takeoff").font(.caption2); Spacer()
            Text("Green clear, orange partly cloudy, grey under cloud").font(.caption2).foregroundStyle(.secondary); Spacer()
            Text("Landing").font(.caption2)
        }
    }

    private func color(_ v: GroundVisibility) -> Color {
        switch v {
        case .clear: return .green.opacity(0.7)
        case .partial: return .orange.opacity(0.7)
        case .obscured: return .gray.opacity(0.6)
        case .unknown: return .secondary.opacity(0.2)
        }
    }
}
