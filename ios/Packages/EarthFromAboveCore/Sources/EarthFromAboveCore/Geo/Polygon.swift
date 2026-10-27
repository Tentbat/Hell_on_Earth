import Foundation

/// A simple polygon in local metres, used for photo footprints.
public struct LocalPolygon: Sendable {
    public var points: [(x: Double, y: Double)]
    public init(points: [(x: Double, y: Double)]) { self.points = points }

    /// Ray casting point-in-polygon test.
    public func contains(x: Double, y: Double) -> Bool {
        var inside = false
        var j = points.count - 1
        for i in 0..<points.count {
            let (xi, yi) = points[i]
            let (xj, yj) = points[j]
            if (yi > y) != (yj > y) {
                let xCross = (xj - xi) * (y - yi) / (yj - yi) + xi
                if x < xCross { inside.toggle() }
            }
            j = i
        }
        return inside
    }
}

/// A geographic polygon (ring of coordinates), used for footprints and areas.
public struct GeoPolygon: Codable, Sendable {
    public var ring: [Coordinate]
    public init(ring: [Coordinate]) { self.ring = ring }

    /// Point-in-polygon using a local flat projection centred on the ring's centroid.
    public func contains(_ c: Coordinate) -> Bool {
        guard ring.count >= 3 else { return false }
        let origin = centroid
        let local = LocalPolygon(points: ring.map {
            let o = Geodesy.localOffset(of: $0, from: origin)
            return (x: o.east, y: o.north)
        })
        let p = Geodesy.localOffset(of: c, from: origin)
        return local.contains(x: p.east, y: p.north)
    }

    public var centroid: Coordinate {
        let lat = ring.map(\.latitude).reduce(0, +) / Double(ring.count)
        let lon = ring.map(\.longitude).reduce(0, +) / Double(ring.count)
        return Coordinate(latitude: lat, longitude: lon)
    }
}
