import Foundation

/// Pose of the camera at the moment a photo was taken, in aircraft terms.
public struct CameraPose: Codable, Sendable {
    /// Aircraft position.
    public var position: Coordinate
    /// Height above the ground directly below, in metres. Use altitude minus terrain
    /// elevation if known, else altitude above sea level as a fair approximation over
    /// low terrain.
    public var heightAboveGroundMeters: Double
    /// Aircraft track in degrees true.
    public var trackDegrees: Double
    /// Which window the camera is pointing out of.
    public var side: CabinSide
    /// Angle below horizontal of the camera's optical axis, degrees. 0 is the horizon,
    /// 90 is straight down. From the device gyroscope.
    public var depressionDegrees: Double
    /// Rotation of the optical axis away from perpendicular-to-the-fuselage, degrees.
    /// Positive turns the camera towards the nose. From device yaw relative to the
    /// window normal; 0 when unknown.
    public var yawOffsetDegrees: Double
    /// Horizontal and vertical field of view of the camera, degrees.
    public var horizontalFOVDegrees: Double
    public var verticalFOVDegrees: Double

    public init(position: Coordinate, heightAboveGroundMeters: Double, trackDegrees: Double, side: CabinSide,
                depressionDegrees: Double, yawOffsetDegrees: Double = 0,
                horizontalFOVDegrees: Double = 69, verticalFOVDegrees: Double = 54) {
        self.position = position
        self.heightAboveGroundMeters = heightAboveGroundMeters
        self.trackDegrees = trackDegrees
        self.side = side
        self.depressionDegrees = depressionDegrees
        self.yawOffsetDegrees = yawOffsetDegrees
        self.horizontalFOVDegrees = horizontalFOVDegrees
        self.verticalFOVDegrees = verticalFOVDegrees
    }

    /// Compass bearing of the optical axis.
    public var axisBearingDegrees: Double {
        let perpendicular = side == .left ? trackDegrees - 90 : trackDegrees + 90
        let towardsNose = side == .left ? yawOffsetDegrees : -yawOffsetDegrees
        return Geodesy.normalizeBearing(perpendicular + towardsNose)
    }
}

/// The patch of ground covered by a photo.
public struct GroundFootprint: Codable, Sendable {
    public var polygon: GeoPolygon
    public var center: Coordinate
    public var centerDistanceMeters: Double
    /// True when the top of the frame is above the horizon, meaning the far edge is
    /// clamped to the horizon and the footprint is open-ended.
    public var includesHorizon: Bool
}

public enum CameraGeometry {
    /// Ground distance for a ray `depression` degrees below horizontal from `height`
    /// metres, clamped to the horizon. Flat-earth for near rays, which is accurate
    /// to about 1 percent inside 100 km; curvature is handled by the horizon clamp.
    public static func groundDistance(heightMeters: Double, depressionDegrees: Double) -> (distance: Double, clampedToHorizon: Bool) {
        let horizon = Geodesy.horizonDistance(altitudeMeters: heightMeters)
        guard depressionDegrees > 0.05 else { return (horizon, true) }
        let d = heightMeters / tan(Geodesy.radians(min(89.99, depressionDegrees)))
        return d >= horizon ? (horizon, true) : (d, false)
    }

    /// Projects the four corners of the frame onto the ground.
    public static func footprint(for pose: CameraPose) -> GroundFootprint {
        let h = max(10, pose.heightAboveGroundMeters)
        let halfV = pose.verticalFOVDegrees / 2
        let halfH = pose.horizontalFOVDegrees / 2
        let axis = pose.axisBearingDegrees

        let (centerDist, _) = groundDistance(heightMeters: h, depressionDegrees: pose.depressionDegrees)
        let center = Geodesy.destination(from: pose.position, bearingDegrees: axis, distanceMeters: centerDist)

        // Near edge (bottom of frame) and far edge (top of frame).
        let (nearDist, _) = groundDistance(heightMeters: h, depressionDegrees: pose.depressionDegrees + halfV)
        let (farDist, farClamped) = groundDistance(heightMeters: h, depressionDegrees: pose.depressionDegrees - halfV)

        // Horizontal half-angle widens the footprint; width grows with distance.
        func corner(distance: Double, sign: Double) -> Coordinate {
            let bearing = axis + sign * halfH
            // The slant range along the edge ray is a little longer than along the axis.
            let d = distance / cos(Geodesy.radians(halfH))
            return Geodesy.destination(from: pose.position, bearingDegrees: bearing, distanceMeters: d)
        }
        let ring = [
            corner(distance: nearDist, sign: -1),
            corner(distance: farDist, sign: -1),
            corner(distance: farDist, sign: 1),
            corner(distance: nearDist, sign: 1)
        ]
        return GroundFootprint(polygon: GeoPolygon(ring: ring), center: center,
                               centerDistanceMeters: centerDist, includesHorizon: farClamped)
    }

    /// Candidate features for a photo, best first. Score combines salience, apparent
    /// size (feature radius over distance) and closeness to the frame centre.
    public static func candidates(for pose: CameraPose, in index: FeatureIndex, limit: Int = 8) -> [PhotoCandidate] {
        let fp = footprint(for: pose)
        let inside = index.inside(fp.polygon)
        var scored: [PhotoCandidate] = inside.map { f in
            let d = max(500, Geodesy.distance(pose.position, f.coordinate))
            let apparent = min(1, f.radiusMeters / d * 10)          // 0...1
            let offAxis = abs(Geodesy.bearingDelta(from: pose.axisBearingDegrees,
                                                   to: Geodesy.bearing(from: pose.position, to: f.coordinate)))
            let centrality = max(0, 1 - offAxis / max(1, pose.horizontalFOVDegrees))   // 0...1
            let score = 0.45 * f.salience + 0.35 * apparent + 0.20 * centrality
            return PhotoCandidate(feature: f, distanceMeters: d, score: score,
                                  relativeBearingDegrees: SideOfTrack.relativeBearing(to: f.coordinate, from: pose.position, trackDegrees: pose.trackDegrees))
        }
        scored.sort { $0.score > $1.score }
        return Array(scored.prefix(limit))
    }
}

public struct PhotoCandidate: Codable, Identifiable, Sendable {
    public var feature: Feature
    public var distanceMeters: Double
    public var score: Double
    public var relativeBearingDegrees: Double
    public var id: String { feature.id }
}
