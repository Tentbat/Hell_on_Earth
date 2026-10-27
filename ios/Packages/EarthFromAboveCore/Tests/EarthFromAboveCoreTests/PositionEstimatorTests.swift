import XCTest
@testable import EarthFromAboveCore

final class PositionEstimatorTests: XCTestCase {
    let sea = Coordinate(47.449, -122.309)
    let den = Coordinate(39.856, -104.673)
    lazy var route = RouteModel.synthesize(waypoints: [sea, den])
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testNoTakeoffNoEstimate() {
        let e = PositionEstimator(route: route)
        XCTAssertNil(e.estimate(at: t0))
    }

    func testDeadReckoningFollowsSchedule() {
        var e = PositionEstimator(route: route)
        e.markTakeoff(at: t0)
        let est = e.estimate(at: t0.addingTimeInterval(3600))!
        XCTAssertEqual(est.source, .deadReckoning)
        let expected = route.sample(atElapsed: 3600)
        XCTAssertEqual(Geodesy.distance(est.coordinate, expected.coordinate), 0, accuracy: 10)
        XCTAssertEqual(est.confidence, .low)
    }

    func testGPSFixIsPreferredAndReanchorsSchedule() {
        var e = PositionEstimator(route: route)
        e.markTakeoff(at: t0)
        // The aircraft is actually 5 minutes ahead of schedule at t+60min.
        let actual = route.sample(atElapsed: 3900)
        e.ingest(PositionFix(coordinate: actual.coordinate, altitudeMeters: actual.altitudeMeters,
                             trackDegrees: actual.trackDegrees, groundSpeedMetersPerSecond: actual.groundSpeedMetersPerSecond,
                             horizontalAccuracyMeters: 30, time: t0.addingTimeInterval(3600), source: .gps))
        let fresh = e.estimate(at: t0.addingTimeInterval(3610))!
        XCTAssertEqual(fresh.source, .gps)
        XCTAssertEqual(fresh.confidence, .high)
        XCTAssertEqual(e.scheduleOffsetSeconds, 300, accuracy: 30)

        // Twenty minutes later with no new fix, dead reckoning should carry the offset.
        let later = e.estimate(at: t0.addingTimeInterval(3600 + 1200))!
        XCTAssertEqual(later.source, .deadReckoning)
        let expected = route.sample(atElapsed: 4800 + 300)
        XCTAssertEqual(Geodesy.distance(later.coordinate, expected.coordinate), 0, accuracy: 3_000)
        XCTAssertEqual(e.remainingSeconds(at: t0.addingTimeInterval(4800))!, route.totalDurationSeconds - 5100, accuracy: 1)
    }

    func testAirborneFixInfersTakeoffWhenButtonMissed() {
        var e = PositionEstimator(route: route)
        let actual = route.sample(atElapsed: 2400)
        e.ingest(PositionFix(coordinate: actual.coordinate, groundSpeedMetersPerSecond: 240,
                             time: t0.addingTimeInterval(2400), source: .gps))
        XCTAssertNotNil(e.takeoffTime)
        XCTAssertEqual(e.takeoffTime!.timeIntervalSince(t0), 0, accuracy: 60)
    }

    func testLowerQualitySourceDoesNotDisplaceFreshGPS() {
        var e = PositionEstimator(route: route)
        e.markTakeoff(at: t0)
        let a = route.sample(atElapsed: 1000)
        e.ingest(PositionFix(coordinate: a.coordinate, time: t0.addingTimeInterval(1000), source: .gps))
        e.ingest(PositionFix(coordinate: den, time: t0.addingTimeInterval(1010), source: .adsb))
        XCTAssertEqual(e.lastFix?.source, .gps)
    }

    func testFlightPhaseDetector() {
        var d = FlightPhaseDetector()
        var t = t0
        // Climb: cabin altitude rising 1.5 m/s for 3 minutes.
        for i in 0..<36 { t = t0.addingTimeInterval(Double(i) * 5); d.add(.init(cabinAltitudeMeters: Double(i) * 7.5, time: t)) }
        XCTAssertEqual(d.phase, .climb)
        // Level for 3 minutes.
        for i in 0..<36 { t = t.addingTimeInterval(5); d.add(.init(cabinAltitudeMeters: 270 + Double(i % 2), time: t)) }
        XCTAssertEqual(d.phase, .cruise)
        // Descend.
        for i in 0..<36 { t = t.addingTimeInterval(5); d.add(.init(cabinAltitudeMeters: 270 - Double(i) * 7.5, time: t)) }
        XCTAssertEqual(d.phase, .descent)
    }
}
