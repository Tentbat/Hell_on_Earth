import SwiftUI
import MapKit
import EarthFromAboveCore

struct FlightMapView: View {
    @Environment(AppState.self) private var app
    @State private var position: MapCameraPosition = .automatic
    @State private var selected: Feature?

    var body: some View {
        NavigationStack {
            Group {
                if let b = app.bundle {
                    ZStack(alignment: .bottom) {
                        Map(position: $position, selection: $selected) {
                            MapPolyline(coordinates: b.route.points.map { CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) })
                                .stroke(.blue, lineWidth: 3)
                            ForEach(b.features.filter { app.settings.interests.includes($0.category) && $0.salience >= 0.5 }) { f in
                                Marker(f.name, systemImage: f.category.symbolName,
                                       coordinate: CLLocationCoordinate2D(latitude: f.coordinate.latitude, longitude: f.coordinate.longitude))
                                    .tint(.orange)
                                    .tag(f)
                            }
                            if let est = app.estimate {
                                Annotation("You", coordinate: CLLocationCoordinate2D(latitude: est.coordinate.latitude, longitude: est.coordinate.longitude)) {
                                    Image(systemName: "airplane")
                                        .font(.title2).foregroundStyle(.white)
                                        .padding(6).background(Circle().fill(.blue))
                                        .rotationEffect(.degrees(est.trackDegrees - 90))
                                }
                                MapCircle(center: CLLocationCoordinate2D(latitude: est.coordinate.latitude, longitude: est.coordinate.longitude), radius: est.uncertaintyMeters)
                                    .foregroundStyle(.blue.opacity(0.12))
                                    .stroke(.blue.opacity(0.4), lineWidth: 1)
                            }
                        }
                        .mapStyle(.hybrid(elevation: .realistic))
                        .mapControls { MapCompass(); MapScaleView() }

                        if let est = app.estimate {
                            HStack(spacing: 8) {
                                StatTile(title: "Elapsed", value: UnitFormat.clock(est.elapsedSeconds))
                                StatTile(title: "Remaining", value: app.remainingSeconds.map { UnitFormat.duration($0) } ?? "–")
                                StatTile(title: "Altitude", value: UnitFormat.feet(fromMeters: est.altitudeMeters))
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                        }
                    }
                    .sheet(item: $selected) { f in
                        NavigationStack { FeatureDetailView(feature: f, kidBand: nil) }.presentationDetents([.medium, .large])
                    }
                    .toolbar {
                        Button {
                            if let est = app.estimate {
                                position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: est.coordinate.latitude, longitude: est.coordinate.longitude),
                                                                      latitudinalMeters: 300_000, longitudinalMeters: 300_000))
                            } else { position = .automatic }
                        } label: { Image(systemName: "location") }
                    }
                } else {
                    EmptyFlightView()
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
