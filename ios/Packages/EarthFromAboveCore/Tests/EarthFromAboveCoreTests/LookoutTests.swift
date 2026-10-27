import XCTest
@testable import EarthFromAboveCore

final class LookoutTests: XCTestCase {
    let sea = Coordinate(47.449, -122.309)
    let den = Coordinate(39.856, -104.673)

    func makeBundle() -> RouteBundle {
        let route = RouteModel.synthesize(waypoints: [sea, den])
        let mid = route.sample(atElapsed: route.totalDurationSeconds / 2)
        let leftOfTrack = Geodesy.destination(from: mid.coordinate, bearingDegrees: mid.trackDegrees - 90, distanceMeters: 30_000)
        let rightOfTrack = Geodesy.destination(from: mid.coordinate, bearingDegrees: mid.trackDegrees + 90, distanceMeters: 30_000)
        let farAway = Geodesy.destination(from: mid.coordinate, bearingDegrees: mid.trackDegrees + 90, distanceMeters: 300_000)
        let features = [
            Feature(id: "L", name: "Left Lake", category: .lake, coordinate: leftOfTrack, salience: 0.7, summary: "A lake"),
            Feature(id: "R", name: "Right Volcano", category: .volcano, coordinate: rightOfTrack, salience: 0.9, summary: "A volcano"),
            Feature(id: "F", name: "Far Thing", category: .city, coordinate: farAway, salience: 1.0, summary: "Too far")
        ]
        // A north-south line crossing the route near the midpoint.
        let line = LineFeature(id: "border", name: "State line", category: .border,
                               points: [Coordinate(mid.coordinate.latitude + 2, mid.coordinate.longitude),
                                        Coordinate(mid.coordinate.latitude - 2, mid.coordinate.longitude)],
                               summary: "A border", leftRegion: "West", rightRegion: "East")
        let clouds = [CloudSample(elapsedSeconds: 0, cloudFraction: 0.1), CloudSample(elapsedSeconds: route.totalDurationSeconds, cloudFraction: 0.9)]
        return RouteBundle(flight: FlightInfo(flightNumber: "TEST1", originCode: "SEA", originName: "Seattle",
                                              destinationCode: "DEN", destinationName: "Denver"),
                           route: route, features: features, lines: [line], clouds: clouds)
    }

    func testTimelineSidesAndRange() {
        let planner = LookoutPlanner(bundle: makeBundle())
        let items = planner.timeline()
        let names = items.map(\.name)
        XCTAssertTrue(names.contains("Left Lake"))
        XCTAssertTrue(names.contains("Right Volcano"))
        XCTAssertFalse(names.contains("Far Thing"))
        XCTAssertEqual(items.first { $0.name == "Left Lake" }?.side, .left)
        XCTAssertEqual(items.first { $0.name == "Right Volcano" }?.side, .right)
        let crossing = items.first { !$0.isFeature }
        XCTAssertNotNil(crossing)
        XCTAssertTrue(crossing!.name.hasPrefix("Entering "))
    }

    func testUserSideFilterAndInterests() {
        var planner = LookoutPlanner(bundle: makeBundle())
        XCTAssertEqual(planner.timeline(userSide: .left).filter(\.isFeature).map(\.name), ["Left Lake"])
        planner.interests = InterestProfile(selected: [.volcano])
        XCTAssertEqual(planner.timeline().filter(\.isFeature).map(\.name), ["Right Volcano"])
    }

    func testVisibilityWindows() {
        let b = makeBundle()
        let v = VisibilityModel(samples: b.clouds)
        XCTAssertEqual(v.visibility(atElapsed: 0), .clear)
        XCTAssertEqual(v.visibility(atElapsed: b.route.totalDurationSeconds), .obscured)
        let w = v.windows(totalDurationSeconds: b.route.totalDurationSeconds)
        XCTAssertEqual(w.map(\.visibility), [.clear, .partial, .obscured])
    }

    func testBingoCardHasNineSquares() {
        let planner = LookoutPlanner(bundle: makeBundle())
        let card = KidMode.bingoCard(from: planner.timeline(), userSide: nil)
        XCTAssertEqual(card.count, 9)
        XCTAssertEqual(Set(card.map(\.id)).count, 9)
    }

    func testBundleRoundTripsThroughJSON() throws {
        let b = makeBundle()
        let data = try RouteBundle.encoder.encode(b)
        let back = try RouteBundle.decoder.decode(RouteBundle.self, from: data)
        XCTAssertEqual(back.features.count, 3)
        XCTAssertEqual(back.route.points.count, b.route.points.count)
    }
}
