import Foundation

/// One sample along the predicted or actual track.
public struct RoutePoint: Codable, Hashable, Sendable {
    public var coordinate: Coordinate
    /// Altitude above mean sea level in metres.
    public var altitudeMeters: Double
    /// Seconds after takeoff at which the aircraft is expected here.
    public var elapsedSeconds: Double

    public init(coordinate: Coordinate, altitudeMeters: Double, elapsedSeconds: Double) {
        self.coordinate = coordinate
        self.altitudeMeters = altitudeMeters
        self.elapsedSeconds = elapsedSeconds
    }
}

/// Typical performance profile for a narrow-body or wide-body jet, used to turn a
/// bare list of waypoints into a timed track when no historical track is available.
public struct SpeedProfile: Codable, Sendable {
    public var climbRateMetersPerSecond: Double
    public var descentRateMetersPerSecond: Double
    public var cruiseGroundSpeedMetersPerSecond: Double
    public var climbGroundSpeedMetersPerSecond: Double
    public var descentGroundSpeedMetersPerSecond: Double
    public var cruiseAltitudeMeters: Double

    public init(climbRateMetersPerSecond: Double = 10.0,
                descentRateMetersPerSecond: Double = 8.0,
                cruiseGroundSpeedMetersPerSecond: Double = 240.0,
                climbGroundSpeedMetersPerSecond: Double = 160.0,
                descentGroundSpeedMetersPerSecond: Double = 170.0,
                cruiseAltitudeMeters: Double = 11_000) {
        self.climbRateMetersPerSecond = climbRateMetersPerSecond
        self.descentRateMetersPerSecond = descentRateMetersPerSecond
        self.cruiseGroundSpeedMetersPerSecond = cruiseGroundSpeedMetersPerSecond
        self.climbGroundSpeedMetersPerSecond = climbGroundSpeedMetersPerSecond
        self.descentGroundSpeedMetersPerSecond = descentGroundSpeedMetersPerSecond
        self.cruiseAltitudeMeters = cruiseAltitudeMeters
    }

    public static let standardJet = SpeedProfile()
}

/// A timed polyline from takeoff to touchdown.
public struct RouteModel: Codable, Sendable {
    public private(set) var points: [RoutePoint]

    public init(points: [RoutePoint]) {
        precondition(points.count >= 2, "A route needs at least two points")
        self.points = points.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
    }

    public var totalDurationSeconds: Double { points.last!.elapsedSeconds }
    public var origin: Coordinate { points.first!.coordinate }
    public var destination: Coordinate { points.last!.coordinate }

    public var totalDistanceMeters: Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + Geodesy.distance($1.0.coordinate, $1.1.coordinate) }
    }

    /// Interpolated position, altitude and track at `elapsed` seconds after takeoff.
    public func sample(atElapsed elapsed: Double) -> RouteSample {
        let t = max(0, min(totalDurationSeconds, elapsed))
        if t <= points.first!.elapsedSeconds {
            let p = points[0]
            return RouteSample(coordinate: p.coordinate, altitudeMeters: p.altitudeMeters,
                               trackDegrees: Geodesy.bearing(from: p.coordinate, to: points[1].coordinate),
                               groundSpeedMetersPerSecond: segmentSpeed(0), elapsedSeconds: t, segmentIndex: 0)
        }
        var i = 0
        while i < points.count - 2 && points[i + 1].elapsedSeconds < t { i += 1 }
        let a = points[i], b = points[i + 1]
        let span = max(1e-6, b.elapsedSeconds - a.elapsedSeconds)
        let f = max(0, min(1, (t - a.elapsedSeconds) / span))
        let c = Geodesy.intermediate(a.coordinate, b.coordinate, fraction: f)
        let alt = a.altitudeMeters + (b.altitudeMeters - a.altitudeMeters) * f
        return RouteSample(coordinate: c, altitudeMeters: alt,
                           trackDegrees: Geodesy.bearing(from: a.coordinate, to: b.coordinate),
                           groundSpeedMetersPerSecond: segmentSpeed(i), elapsedSeconds: t, segmentIndex: i)
    }

    private func segmentSpeed(_ i: Int) -> Double {
        let a = points[i], b = points[i + 1]
        let d = Geodesy.distance(a.coordinate, b.coordinate)
        let dt = max(1e-6, b.elapsedSeconds - a.elapsedSeconds)
        return d / dt
    }

    /// Finds the elapsed time at which the route passes closest to `coordinate`.
    /// Used to re-anchor dead reckoning when a real fix arrives.
    public func elapsedTime(closestTo coordinate: Coordinate) -> (elapsed: Double, distanceMeters: Double) {
        var best = (elapsed: 0.0, distanceMeters: Double.infinity)
        for i in 0..<(points.count - 1) {
            let a = points[i], b = points[i + 1]
            let segLen = Geodesy.distance(a.coordinate, b.coordinate)
            guard segLen > 1 else { continue }
            let along = Geodesy.alongTrackDistance(point: coordinate, start: a.coordinate, end: b.coordinate)
            let f = max(0, min(1, along / segLen))
            let p = Geodesy.intermediate(a.coordinate, b.coordinate, fraction: f)
            let d = Geodesy.distance(p, coordinate)
            if d < best.distanceMeters {
                best = (a.elapsedSeconds + (b.elapsedSeconds - a.elapsedSeconds) * f, d)
            }
        }
        return best
    }

    /// Builds a timed route from bare waypoints using a speed profile.
    /// Climb and descent are modelled as constant-rate segments; cruise is level.
    public static func synthesize(waypoints: [Coordinate],
                                  originElevationMeters: Double = 0,
                                  destinationElevationMeters: Double = 0,
                                  profile: SpeedProfile = .standardJet,
                                  sampleSpacingMeters: Double = 10_000) -> RouteModel {
        precondition(waypoints.count >= 2)
        // Densify the polyline.
        var dense: [Coordinate] = []
        for (a, b) in zip(waypoints, waypoints.dropFirst()) {
            let d = Geodesy.distance(a, b)
            let n = max(1, Int(d / sampleSpacingMeters))
            for k in 0..<n { dense.append(Geodesy.intermediate(a, b, fraction: Double(k) / Double(n))) }
        }
        dense.append(waypoints.last!)

        var cumulative: [Double] = [0]
        for (a, b) in zip(dense, dense.dropFirst()) { cumulative.append(cumulative.last! + Geodesy.distance(a, b)) }
        let total = cumulative.last!

        let climbHeight = max(0, profile.cruiseAltitudeMeters - originElevationMeters)
        let descentHeight = max(0, profile.cruiseAltitudeMeters - destinationElevationMeters)
        var climbDist = climbHeight / profile.climbRateMetersPerSecond * profile.climbGroundSpeedMetersPerSecond
        var descentDist = descentHeight / profile.descentRateMetersPerSecond * profile.descentGroundSpeedMetersPerSecond
        // Short flights never reach cruise: scale both down so they meet in the middle.
        if climbDist + descentDist > total {
            let scale = total / (climbDist + descentDist)
            climbDist *= scale
            descentDist *= scale
        }
        let cruiseStart = climbDist
        let cruiseEnd = total - descentDist
        let climbTime = climbDist / profile.climbGroundSpeedMetersPerSecond
        let cruiseTime = max(0, cruiseEnd - cruiseStart) / profile.cruiseGroundSpeedMetersPerSecond
        let topAltitude = climbDist + descentDist >= total
            ? originElevationMeters + climbDist / profile.climbGroundSpeedMetersPerSecond * profile.climbRateMetersPerSecond
            : profile.cruiseAltitudeMeters

        var pts: [RoutePoint] = []
        for (i, c) in dense.enumerated() {
            let s = cumulative[i]
            let elapsed: Double
            let alt: Double
            if s <= cruiseStart {
                let f = climbDist > 0 ? s / climbDist : 1
                elapsed = s / profile.climbGroundSpeedMetersPerSecond
                alt = originElevationMeters + (topAltitude - originElevationMeters) * f
            } else if s <= cruiseEnd {
                elapsed = climbTime + (s - cruiseStart) / profile.cruiseGroundSpeedMetersPerSecond
                alt = topAltitude
            } else {
                let f = descentDist > 0 ? (s - cruiseEnd) / descentDist : 1
                elapsed = climbTime + cruiseTime + (s - cruiseEnd) / profile.descentGroundSpeedMetersPerSecond
                alt = topAltitude - (topAltitude - destinationElevationMeters) * f
            }
            pts.append(RoutePoint(coordinate: c, altitudeMeters: alt, elapsedSeconds: elapsed))
        }
        return RouteModel(points: pts)
    }
}

public struct RouteSample: Sendable {
    public var coordinate: Coordinate
    public var altitudeMeters: Double
    public var trackDegrees: Double
    public var groundSpeedMetersPerSecond: Double
    public var elapsedSeconds: Double
    public var segmentIndex: Int
}
