import XCTest
@testable import EarthFromAboveCore

final class CameraGeometryTests: XCTestCase {
    func testGroundDistanceAt45Degrees() {
        let r = CameraGeometry.groundDistance(heightMeters: 10_000, depressionDegrees: 45)
        XCTAssertEqual(r.distance, 10_000, accuracy: 1)
        XCTAssertFalse(r.clampedToHorizon)
    }

    func testShallowAngleClampsToHorizon() {
        let r = CameraGeometry.groundDistance(heightMeters: 10_000, depressionDegrees: 0.5)
        XCTAssertTrue(r.clampedToHorizon)
        XCTAssertEqual(r.distance, Geodesy.horizonDistance(altitudeMeters: 10_000), accuracy: 1)
    }

    func testAxisBearingLeftWindow() {
        let pose = CameraPose(position: Coordinate(40, -105), heightAboveGroundMeters: 10_000, trackDegrees: 90,
                              side: .left, depressionDegrees: 30)
        XCTAssertEqual(pose.axisBearingDegrees, 0, accuracy: 1e-9)   // flying east, left window looks north
        var right = pose; right.side = .right
        XCTAssertEqual(right.axisBearingDegrees, 180, accuracy: 1e-9)
    }

    func testFootprintContainsExpectedPoint() {
        let pos = Coordinate(40, -105)
        let pose = CameraPose(position: pos, heightAboveGroundMeters: 10_000, trackDegrees: 90, side: .left, depressionDegrees: 30)
        let fp = CameraGeometry.footprint(for: pose)
        // Centre should be about 17.3 km north.
        XCTAssertEqual(fp.centerDistanceMeters, 17_320, accuracy: 50)
        XCTAssertTrue(fp.polygon.contains(fp.center))
        let behind = Geodesy.destination(from: pos, bearingDegrees: 180, distanceMeters: 17_000)
        XCTAssertFalse(fp.polygon.contains(behind))
        XCTAssertFalse(fp.includesHorizon)
    }

    func testCandidatesRankInFrameFeatureFirst() {
        let pos = Coordinate(40, -105)
        let inFrame = Geodesy.destination(from: pos, bearingDegrees: 0, distanceMeters: 17_000)
        let outOfFrame = Geodesy.destination(from: pos, bearingDegrees: 180, distanceMeters: 17_000)
        let index = FeatureIndex(features: [
            Feature(id: "a", name: "Target Lake", category: .lake, coordinate: inFrame, radiusMeters: 3000, salience: 0.6, summary: ""),
            Feature(id: "b", name: "Wrong Side Dam", category: .reservoirDam, coordinate: outOfFrame, radiusMeters: 3000, salience: 0.9, summary: "")
        ])
        let pose = CameraPose(position: pos, heightAboveGroundMeters: 10_000, trackDegrees: 90, side: .left, depressionDegrees: 30)
        let c = CameraGeometry.candidates(for: pose, in: index)
        XCTAssertEqual(c.map(\.id), ["a"])
    }

    func testSeatLetterToSide() {
        XCTAssertEqual(CabinSide.fromSeat("14A"), .left)
        XCTAssertEqual(CabinSide.fromSeat("14F"), .right)
        XCTAssertEqual(CabinSide.fromSeat("32K", lettersInRow: 9), .right)
        XCTAssertNil(CabinSide.fromSeat("14C"))
    }
}
