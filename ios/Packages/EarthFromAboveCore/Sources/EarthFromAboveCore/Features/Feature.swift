import Foundation

/// A named thing on the ground (or in the sky) that the app can point out.
public struct Feature: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var category: FeatureCategory
    public var coordinate: Coordinate
    /// Approximate radius of the feature in metres, so a 30 km lake and a 300 m dam
    /// are treated differently when deciding what is "in frame" or "nearby".
    public var radiusMeters: Double
    /// 0...1. How worth pointing out it is, independent of the user's interests.
    public var salience: Double
    /// One or two sentences for the look-out list and offline identification.
    public var summary: String
    /// Longer offline text, Markdown allowed.
    public var detail: String?
    /// Simplified text for kid mode.
    public var kidSummary: String?
    /// Where the summary text came from, for attribution (for example "Wikipedia, CC BY-SA 4.0").
    public var attribution: String?
    /// Optional Wikipedia article title for online deep dives.
    public var wikipediaTitle: String?
    /// Optional spotting tip ("look for the bright white crescent against dark lava").
    public var spottingTip: String?
    /// Elevation of the feature in metres, where it matters (peaks, high plateaus).
    public var elevationMeters: Double?

    public init(id: String, name: String, category: FeatureCategory, coordinate: Coordinate,
                radiusMeters: Double = 2_000, salience: Double = 0.5, summary: String,
                detail: String? = nil, kidSummary: String? = nil, attribution: String? = nil,
                wikipediaTitle: String? = nil, spottingTip: String? = nil, elevationMeters: Double? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.coordinate = coordinate
        self.radiusMeters = radiusMeters
        self.salience = salience
        self.summary = summary
        self.detail = detail
        self.kidSummary = kidSummary
        self.attribution = attribution
        self.wikipediaTitle = wikipediaTitle
        self.spottingTip = spottingTip
        self.elevationMeters = elevationMeters
    }
}

public enum CabinSide: String, Codable, CaseIterable, Sendable {
    case left, right

    public var displayName: String { self == .left ? "Left side" : "Right side" }

    /// Seat letter A is the left (port) side on essentially every airline. The
    /// highest letter in a row is the right side. Returns nil for middle seats or
    /// unknown letters, where the user has to tell us.
    public static func fromSeat(_ seat: String, lettersInRow: Int = 6) -> CabinSide? {
        let letters = seat.uppercased().filter { $0.isLetter }
        guard let letter = letters.last else { return nil }
        if letter == "A" { return .left }
        let lastLetter = Character(UnicodeScalar(UInt8(ascii: "A") + UInt8(max(1, lettersInRow) - 1)))
        if letter == lastLetter { return .right }
        // Common window letters on wide-bodies and regional jets.
        if ["K", "L"].contains(letter) { return .right }
        return nil
    }
}

/// Which side of the aircraft a point is on, given position and track.
public enum SideOfTrack {
    /// Negative cross-track means left of the direction of travel.
    public static func side(of point: Coordinate, from position: Coordinate, trackDegrees: Double) -> CabinSide {
        let ahead = Geodesy.destination(from: position, bearingDegrees: trackDegrees, distanceMeters: 100_000)
        let xt = Geodesy.crossTrackDistance(point: point, start: position, end: ahead)
        return xt < 0 ? .left : .right
    }

    /// Relative bearing of `point` from the aircraft, in degrees clockwise from the nose, [0, 360).
    public static func relativeBearing(to point: Coordinate, from position: Coordinate, trackDegrees: Double) -> Double {
        Geodesy.normalizeBearing(Geodesy.bearing(from: position, to: point) - trackDegrees)
    }
}
