import XCTest
@testable import EarthFromAboveCore

final class RouteModelTests: XCTestCase {
    let sea = Coordinate(47.449, -122.309)
    let den = Coordinate(39.856, -104.673)

    func testSynthesizedRouteHasPlausibleDuration() {
        let r = RouteModel.synthesize(waypoints: [sea, den], originElevationMeters: 130, destinationElevationMeters: 1655)
        // SEA to DEN block time is about 2h30; airborne time around 2h10 to 2h20.
        XCTAssertEqual(r.totalDurationSeconds / 60, 135, accuracy: 20)
        XCTAssertEqual(r.points.first!.altitudeMeters, 130, accuracy: 1)
        XCTAssertEqual(r.points.last!.altitudeMeters, 1655, accuracy: 1)
        let cruise = r.sample(atElapsed: r.totalDurationSeconds / 2)
        XCTAssertEqual(cruise.altitudeMeters, 11_000, accuracy: 1)
    }

    func testSampleInterpolatesMonotonically() {
        let r = RouteModel.synthesize(waypoints: [sea, den])
        var lastLat = 100.0
        for t in stride(from: 0.0, through: r.totalDurationSeconds, by: 300) {
            let s = r.sample(atElapsed: t)
            XCTAssertLessThanOrEqual(s.coordinate.latitude, lastLat + 1e-9)
            lastLat = s.coordinate.latitude
            XCTAssertGreaterThan(s.groundSpeedMetersPerSecond, 100)
        }
    }

    func testShortHopNeverReachesCruise() {
        let lax = Coordinate(33.942, -118.408), san = Coordinate(32.734, -117.190)
        let r = RouteModel.synthesize(waypoints: [lax, san])
        let top = r.points.map(\.altitudeMeters).max()!
        XCTAssertLessThan(top, 11_000)
        XCTAssertGreaterThan(top, 2_000)
    }

    func testClosestElapsedTime() {
        let r = RouteModel.synthesize(waypoints: [sea, den])
        let mid = r.sample(atElapsed: 3600)
        let off = Geodesy.destination(from: mid.coordinate, bearingDegrees: mid.trackDegrees + 90, distanceMeters: 20_000)
        let m = r.elapsedTime(closestTo: off)
        XCTAssertEqual(m.elapsed, 3600, accuracy: 60)
        XCTAssertEqual(m.distanceMeters, 20_000, accuracy: 1_500)
    }
}
