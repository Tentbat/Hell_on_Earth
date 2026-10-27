import Foundation

/// A line on the land that the route may cross: a state or national border, a
/// major river, a continental divide, a time-zone boundary.
public struct LineFeature: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var category: FeatureCategory
    public var points: [Coordinate]
    public var summary: String
    public var kidSummary: String?
    /// For borders: the region on each side, so we can say "entering Nevada".
    public var leftRegion: String?
    public var rightRegion: String?

    public init(id: String, name: String, category: FeatureCategory, points: [Coordinate], summary: String,
                kidSummary: String? = nil, leftRegion: String? = nil, rightRegion: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.points = points
        self.summary = summary
        self.kidSummary = kidSummary
        self.leftRegion = leftRegion
        self.rightRegion = rightRegion
    }
}

public struct CrossingEvent: Codable, Identifiable, Sendable {
    public var id: String
    public var line: LineFeature
    public var coordinate: Coordinate
    public var elapsedSeconds: Double
    /// Region being entered, when the line is a border.
    public var entering: String?
}

public enum Crossings {
    /// Segment intersection in a local flat frame. Returns the fraction along segment
    /// p1->p2 at which it crosses q1->q2, or nil.
    static func intersectionFraction(p1: Coordinate, p2: Coordinate, q1: Coordinate, q2: Coordinate) -> Double? {
        let o = p1
        let a = Geodesy.localOffset(of: p1, from: o), b = Geodesy.localOffset(of: p2, from: o)
        let c = Geodesy.localOffset(of: q1, from: o), d = Geodesy.localOffset(of: q2, from: o)
        let r = (b.east - a.east, b.north - a.north)
        let s = (d.east - c.east, d.north - c.north)
        let denom = r.0 * s.1 - r.1 * s.0
        guard abs(denom) > 1e-9 else { return nil }
        let qp = (c.east - a.east, c.north - a.north)
        let t = (qp.0 * s.1 - qp.1 * s.0) / denom
        let u = (qp.0 * r.1 - qp.1 * r.0) / denom
        guard t >= 0, t <= 1, u >= 0, u <= 1 else { return nil }
        return t
    }

    /// All crossings of `lines` by `route`, in time order.
    public static func events(route: RouteModel, lines: [LineFeature]) -> [CrossingEvent] {
        var out: [CrossingEvent] = []
        let pts = route.points
        for line in lines {
            guard line.points.count >= 2 else { continue }
            for i in 0..<(pts.count - 1) {
                let p1 = pts[i].coordinate, p2 = pts[i + 1].coordinate
                for j in 0..<(line.points.count - 1) {
                    let q1 = line.points[j], q2 = line.points[j + 1]
                    // Cheap bounding-box reject.
                    if max(p1.latitude, p2.latitude) < min(q1.latitude, q2.latitude) - 0.01 { continue }
                    if min(p1.latitude, p2.latitude) > max(q1.latitude, q2.latitude) + 0.01 { continue }
                    if max(p1.longitude, p2.longitude) < min(q1.longitude, q2.longitude) - 0.01 { continue }
                    if min(p1.longitude, p2.longitude) > max(q1.longitude, q2.longitude) + 0.01 { continue }
                    guard let t = intersectionFraction(p1: p1, p2: p2, q1: q1, q2: q2) else { continue }
                    let c = Geodesy.intermediate(p1, p2, fraction: t)
                    let elapsed = pts[i].elapsedSeconds + (pts[i + 1].elapsedSeconds - pts[i].elapsedSeconds) * t
                    // Which side of the line are we heading to? Sign of cross product of line dir and route dir.
                    var entering: String? = nil
                    if line.leftRegion != nil || line.rightRegion != nil {
                        let o = q1
                        let l = Geodesy.localOffset(of: q2, from: o)
                        let r = Geodesy.localOffset(of: p2, from: o)
                        let r0 = Geodesy.localOffset(of: p1, from: o)
                        let dir = (r.east - r0.east, r.north - r0.north)
                        let cross = l.east * dir.1 - l.north * dir.0
                        entering = cross > 0 ? line.leftRegion : line.rightRegion
                    }
                    out.append(CrossingEvent(id: "\(line.id)-\(Int(elapsed))", line: line, coordinate: c,
                                             elapsedSeconds: elapsed, entering: entering))
                }
            }
        }
        return out.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
    }
}
