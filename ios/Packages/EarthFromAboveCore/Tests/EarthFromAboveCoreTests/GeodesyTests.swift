import XCTest
@testable import EarthFromAboveCore

final class GeodesyTests: XCTestCase {
    let sea = Coordinate(47.449, -122.309)   // SEA
    let den = Coordinate(39.856, -104.673)   // DEN

    func testDistanceSEAtoDEN() {
        let d = Geodesy.distance(sea, den)
        // Published great-circle distance is about 1,640 km.
        XCTAssertEqual(d / 1000, 1640, accuracy: 15)
    }

    func testBearingAndDestinationRoundTrip() {
        let b = Geodesy.bearing(from: sea, to: den)
        XCTAssertGreaterThan(b, 90); XCTAssertLessThan(b, 180)   // south-east
        let d = Geodesy.distance(sea, den)
        let p = Geodesy.destination(from: sea, bearingDegrees: b, distanceMeters: d)
        XCTAssertEqual(p.latitude, den.latitude, accuracy: 0.05)
        XCTAssertEqual(p.longitude, den.longitude, accuracy: 0.05)
    }

    func testIntermediateEndpoints() {
        let a = Geodesy.intermediate(sea, den, fraction: 0)
        let b = Geodesy.intermediate(sea, den, fraction: 1)
        XCTAssertEqual(a.latitude, sea.latitude, accuracy: 1e-6)
        XCTAssertEqual(b.longitude, den.longitude, accuracy: 1e-6)
    }

    func testCrossTrackSign() {
        // Track due east along the equator; a point north is on the left.
        let start = Coordinate(0, 0), end = Coordinate(0, 1)
        let north = Coordinate(0.1, 0.5), south = Coordinate(-0.1, 0.5)
        XCTAssertLessThan(Geodesy.crossTrackDistance(point: north, start: start, end: end), 0)
        XCTAssertGreaterThan(Geodesy.crossTrackDistance(point: south, start: start, end: end), 0)
        XCTAssertEqual(abs(Geodesy.crossTrackDistance(point: north, start: start, end: end)), 11_100, accuracy: 100)
    }

    func testHorizonDistanceAtCruise() {
        // From 11 km up the horizon is roughly 400 km away with refraction.
        XCTAssertEqual(Geodesy.horizonDistance(altitudeMeters: 11_000) / 1000, 404, accuracy: 10)
    }

    func testBearingDelta() {
        XCTAssertEqual(Geodesy.bearingDelta(from: 350, to: 10), 20, accuracy: 1e-9)
        XCTAssertEqual(Geodesy.bearingDelta(from: 10, to: 350), -20, accuracy: 1e-9)
    }
}
