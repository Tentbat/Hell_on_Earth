import Foundation
import CoreLocation
import EarthFromAboveCore

/// Wraps CLLocationManager. GPS works at cruise altitude in a window seat; the
/// first fix can take a minute or two because the receiver has to find
/// satellites without network assistance. We ask for background updates so the
/// flight keeps being tracked with the phone locked.
final class LocationService: NSObject, CLLocationManagerDelegate {
    var onFix: ((PositionFix) -> Void)?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 250
        manager.activityType = .airborne
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            begin()
        default:
            break
        }
    }

    func requestAlwaysAuthorization() { manager.requestAlwaysAuthorization() }

    private func begin() {
        if manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways { begin() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last, l.horizontalAccuracy >= 0, l.horizontalAccuracy < 5_000 else { return }
        let fix = PositionFix(coordinate: Coordinate(latitude: l.coordinate.latitude, longitude: l.coordinate.longitude),
                              altitudeMeters: l.verticalAccuracy >= 0 ? l.altitude : nil,
                              trackDegrees: l.course >= 0 ? l.course : nil,
                              groundSpeedMetersPerSecond: l.speed >= 0 ? l.speed : nil,
                              horizontalAccuracyMeters: l.horizontalAccuracy,
                              time: l.timestamp, source: .gps)
        onFix?(fix)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorLocationUnknown is routine while the receiver searches for satellites.
    }
}
