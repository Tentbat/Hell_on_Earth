import SwiftUI
import EarthFromAboveCore

struct SideBadge: View {
    var side: CabinSide?
    var body: some View {
        Label(side?.displayName ?? "Below you", systemImage: side == .left ? "arrow.left" : side == .right ? "arrow.right" : "arrow.down")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
    }
}

struct VisibilityBadge: View {
    var visibility: GroundVisibility
    var body: some View {
        let (icon, color): (String, Color) = {
            switch visibility {
            case .clear: return ("sun.max", .green)
            case .partial: return ("cloud.sun", .orange)
            case .obscured: return ("cloud.fill", .gray)
            case .unknown: return ("questionmark.circle", .secondary)
            }
        }()
        Label(visibility.displayName, systemImage: icon).font(.caption).foregroundStyle(color)
    }
}

struct CategoryIcon: View {
    var category: FeatureCategory
    var body: some View {
        Image(systemName: category.symbolName).frame(width: 28)
    }
}

extension FeatureCategory {
    var symbolName: String {
        switch group {
        case .geology: return "mountain.2"
        case .ecology: return "leaf"
        case .water: return "drop"
        case .humanLandscape: return "building.2"
        case .history: return "building.columns"
        case .sky: return "cloud.sun"
        }
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
    }
}

struct EmptyFlightView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        ContentUnavailableView {
            Label("No flight loaded", systemImage: "airplane.circle")
        } description: {
            Text("Set up your flight on the Flight tab, or load the sample flight to explore.")
        } actions: {
            Button("Load sample flight") { app.loadSampleBundle() }.buttonStyle(.borderedProminent)
        }
    }
}

struct FeatureDetailView: View {
    var feature: Feature
    var kidBand: KidBand?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack { CategoryIcon(category: feature.category); Text(feature.category.displayName).foregroundStyle(.secondary) }
                Text(kidBand != nil ? (feature.kidSummary ?? feature.summary) : feature.summary).font(.body)
                if let tip = feature.spottingTip {
                    Label(tip, systemImage: "eye").font(.callout).padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(0.15)))
                }
                if kidBand == nil, let detail = feature.detail {
                    Text(LocalizedStringKey(detail)).font(.callout)
                }
                if let a = feature.attribution { Text(a).font(.footnote).foregroundStyle(.secondary) }
                if let e = feature.elevationMeters { Text("Elevation \(UnitFormat.feet(fromMeters: e))").font(.footnote).foregroundStyle(.secondary) }
            }
            .padding()
        }
        .navigationTitle(feature.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
