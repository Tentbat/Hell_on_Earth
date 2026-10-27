import Foundation

/// In-memory spatial index over the features in a route bundle. Bundles hold at
/// most a few thousand features for a corridor, so a simple grid is plenty.
public struct FeatureIndex: Sendable {
    public private(set) var features: [Feature]
    private var grid: [GridKey: [Int]] = [:]
    private let cellDegrees: Double

    private struct GridKey: Hashable { let x: Int; let y: Int }

    public init(features: [Feature], cellDegrees: Double = 0.5) {
        self.features = features
        self.cellDegrees = cellDegrees
        for (i, f) in features.enumerated() {
            grid[key(for: f.coordinate), default: []].append(i)
        }
    }

    private func key(for c: Coordinate) -> GridKey {
        GridKey(x: Int(floor(c.longitude / cellDegrees)), y: Int(floor(c.latitude / cellDegrees)))
    }

    public var count: Int { features.count }

    public func feature(id: String) -> Feature? { features.first { $0.id == id } }

    /// Features whose centre lies within `radiusMeters` of `center`, nearest first.
    public func nearby(_ center: Coordinate, radiusMeters: Double) -> [(feature: Feature, distanceMeters: Double)] {
        let latSpan = radiusMeters / 111_000
        let lonSpan = radiusMeters / (111_000 * max(0.1, cos(Geodesy.radians(center.latitude))))
        let minK = key(for: Coordinate(center.latitude - latSpan, center.longitude - lonSpan))
        let maxK = key(for: Coordinate(center.latitude + latSpan, center.longitude + lonSpan))
        var out: [(Feature, Double)] = []
        for x in minK.x...maxK.x {
            for y in minK.y...maxK.y {
                for i in grid[GridKey(x: x, y: y)] ?? [] {
                    let f = features[i]
                    let d = Geodesy.distance(center, f.coordinate)
                    if d <= radiusMeters { out.append((f, d)) }
                }
            }
        }
        return out.sorted { $0.1 < $1.1 }.map { (feature: $0.0, distanceMeters: $0.1) }
    }

    /// Features inside a geographic polygon (a photo footprint). A feature counts as
    /// inside if its centre is inside or its radius overlaps the polygon's centroid
    /// region, so a large lake partly in frame is still reported.
    public func inside(_ polygon: GeoPolygon) -> [Feature] {
        let c = polygon.centroid
        let reach = polygon.ring.map { Geodesy.distance(c, $0) }.max() ?? 0
        return nearby(c, radiusMeters: reach + 50_000).compactMap { item in
            if polygon.contains(item.feature.coordinate) { return item.feature }
            // Large features: accept if the polygon centroid is within the feature's radius.
            if item.distanceMeters <= item.feature.radiusMeters { return item.feature }
            return nil
        }
    }
}
