import Foundation

/// A geographic coordinate in degrees. Kept independent of CoreLocation so the
/// core package stays pure Swift and testable on any platform.
public struct Coordinate: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(_ latitude: Double, _ longitude: Double) {
        self.init(latitude: latitude, longitude: longitude)
    }
}

/// Great-circle geometry on a spherical Earth. Accuracy is well within what the
/// app needs: at cruise altitude the ground footprint of a photo is kilometres
/// across, and the position estimate itself carries larger uncertainty.
public enum Geodesy {
    public static let earthRadiusMeters: Double = 6_371_008.8
    public static let metersPerNauticalMile: Double = 1852.0
    public static let feetPerMeter: Double = 3.280_839_895

    @inlinable public static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    @inlinable public static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

    /// Normalises a bearing to [0, 360).
    public static func normalizeBearing(_ degrees: Double) -> Double {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return d
    }

    /// Signed smallest difference `b - a` in degrees, in (-180, 180].
    public static func bearingDelta(from a: Double, to b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d <= -180 { d += 360 }
        return d
    }

    /// Haversine distance in metres.
    public static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let φ1 = radians(a.latitude), φ2 = radians(b.latitude)
        let dφ = φ2 - φ1
        let dλ = radians(b.longitude - a.longitude)
        let h = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    /// Initial bearing from `a` to `b` in degrees, [0, 360).
    public static func bearing(from a: Coordinate, to b: Coordinate) -> Double {
        let φ1 = radians(a.latitude), φ2 = radians(b.latitude)
        let dλ = radians(b.longitude - a.longitude)
        let y = sin(dλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(dλ)
        return normalizeBearing(degrees(atan2(y, x)))
    }

    /// Point reached travelling `distanceMeters` from `start` along `bearingDegrees`.
    public static func destination(from start: Coordinate, bearingDegrees: Double, distanceMeters: Double) -> Coordinate {
        let δ = distanceMeters / earthRadiusMeters
        let θ = radians(bearingDegrees)
        let φ1 = radians(start.latitude), λ1 = radians(start.longitude)
        let φ2 = asin(sin(φ1) * cos(δ) + cos(φ1) * sin(δ) * cos(θ))
        let λ2 = λ1 + atan2(sin(θ) * sin(δ) * cos(φ1), cos(δ) - sin(φ1) * sin(φ2))
        var lon = degrees(λ2)
        if lon > 180 { lon -= 360 }
        if lon < -180 { lon += 360 }
        return Coordinate(latitude: degrees(φ2), longitude: lon)
    }

    /// Point a fraction `f` (0...1) of the way along the great circle from `a` to `b`.
    public static func intermediate(_ a: Coordinate, _ b: Coordinate, fraction f: Double) -> Coordinate {
        let φ1 = radians(a.latitude), λ1 = radians(a.longitude)
        let φ2 = radians(b.latitude), λ2 = radians(b.longitude)
        let δ = distance(a, b) / earthRadiusMeters
        if δ < 1e-12 { return a }
        let A = sin((1 - f) * δ) / sin(δ)
        let B = sin(f * δ) / sin(δ)
        let x = A * cos(φ1) * cos(λ1) + B * cos(φ2) * cos(λ2)
        let y = A * cos(φ1) * sin(λ1) + B * cos(φ2) * sin(λ2)
        let z = A * sin(φ1) + B * sin(φ2)
        return Coordinate(latitude: degrees(atan2(z, sqrt(x * x + y * y))), longitude: degrees(atan2(y, x)))
    }

    /// Signed cross-track distance of `point` from the great circle through
    /// `start` -> `end`, in metres. Negative means left of the track, positive right.
    public static func crossTrackDistance(point: Coordinate, start: Coordinate, end: Coordinate) -> Double {
        let δ13 = distance(start, point) / earthRadiusMeters
        let θ13 = radians(bearing(from: start, to: point))
        let θ12 = radians(bearing(from: start, to: end))
        return asin(sin(δ13) * sin(θ13 - θ12)) * earthRadiusMeters
    }

    /// Distance along the track from `start` to the point abeam `point`, in metres.
    public static func alongTrackDistance(point: Coordinate, start: Coordinate, end: Coordinate) -> Double {
        let δ13 = distance(start, point) / earthRadiusMeters
        let xt = crossTrackDistance(point: point, start: start, end: end) / earthRadiusMeters
        let c = cos(δ13) / cos(xt)
        return acos(max(-1, min(1, c))) * earthRadiusMeters
    }

    /// Distance to the visible horizon from `altitudeMeters` above a sphere, in metres,
    /// with a standard refraction allowance (effective radius 7/6 R).
    public static func horizonDistance(altitudeMeters: Double) -> Double {
        let r = earthRadiusMeters * 7.0 / 6.0
        return sqrt(max(0, 2 * r * altitudeMeters + altitudeMeters * altitudeMeters))
    }

    /// Flat-earth local offset of `point` from `origin` in metres (east, north).
    /// Good to well under 1 percent for distances under ~200 km.
    public static func localOffset(of point: Coordinate, from origin: Coordinate) -> (east: Double, north: Double) {
        let north = radians(point.latitude - origin.latitude) * earthRadiusMeters
        let east = radians(point.longitude - origin.longitude) * earthRadiusMeters * cos(radians(origin.latitude))
        return (east, north)
    }
}
