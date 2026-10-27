import Foundation

/// One entry on the look-out timeline: a feature passing abeam, or a line crossed.
public struct LookoutItem: Identifiable, Sendable {
    public enum Kind: Sendable { case feature(Feature), crossing(CrossingEvent) }

    public var id: String
    public var kind: Kind
    public var elapsedSeconds: Double
    /// Which window to look out of; nil for crossings and things directly below.
    public var side: CabinSide?
    /// Lateral distance from the track in metres.
    public var lateralDistanceMeters: Double
    public var visibility: GroundVisibility
    public var category: FeatureCategory
    public var name: String
    public var summary: String
    public var kidSummary: String?
    public var spottingTip: String?

    public var isFeature: Bool { if case .feature = kind { return true } else { return false } }
}

/// Builds the "things to look out for" timeline for a bundle, and answers
/// "what is coming up" for the live view.
public struct LookoutPlanner: Sendable {
    public var bundle: RouteBundle
    public var interests: InterestProfile
    public var index: FeatureIndex
    public var visibility: VisibilityModel
    /// Features further than this from the track are not listed. At cruise height
    /// the useful viewing range is about 60 to 80 km on a clear day.
    public var lateralRangeMeters: Double
    /// Features closer than this to the track are "below you" and visible from both sides.
    public var belowThresholdMeters: Double

    public init(bundle: RouteBundle, interests: InterestProfile = .everything,
                lateralRangeMeters: Double = 70_000, belowThresholdMeters: Double = 4_000) {
        self.bundle = bundle
        self.interests = interests
        self.index = FeatureIndex(features: bundle.features)
        self.visibility = VisibilityModel(samples: bundle.clouds)
        self.lateralRangeMeters = lateralRangeMeters
        self.belowThresholdMeters = belowThresholdMeters
    }

    /// The whole flight's timeline, in time order.
    public func timeline(userSide: CabinSide? = nil, minimumSalience: Double = 0.0) -> [LookoutItem] {
        var items: [LookoutItem] = []
        let route = bundle.route
        var seen = Set<String>()

        for f in bundle.features where interests.includes(f.category) && f.salience >= minimumSalience {
            let match = route.elapsedTime(closestTo: f.coordinate)
            guard match.distanceMeters <= lateralRangeMeters + f.radiusMeters else { continue }
            // Skip things on the ground at either end that are not yet visible (we are below 300 m).
            let s = route.sample(atElapsed: match.elapsed)
            guard s.altitudeMeters > 300 || match.distanceMeters < 10_000 else { continue }
            let side: CabinSide? = match.distanceMeters < belowThresholdMeters
                ? nil
                : SideOfTrack.side(of: f.coordinate, from: s.coordinate, trackDegrees: s.trackDegrees)
            if let userSide, let side, side != userSide { continue }
            guard seen.insert(f.id).inserted else { continue }
            items.append(LookoutItem(id: "f-" + f.id, kind: .feature(f), elapsedSeconds: match.elapsed, side: side,
                                     lateralDistanceMeters: match.distanceMeters,
                                     visibility: visibility.visibility(atElapsed: match.elapsed),
                                     category: f.category, name: f.name, summary: f.summary,
                                     kidSummary: f.kidSummary, spottingTip: f.spottingTip))
        }
        for c in Crossings.events(route: route, lines: bundle.lines) where interests.includes(c.line.category) {
            let name = c.entering.map { "Entering \($0)" } ?? "Crossing \(c.line.name)"
            items.append(LookoutItem(id: "c-" + c.id, kind: .crossing(c), elapsedSeconds: c.elapsedSeconds, side: nil,
                                     lateralDistanceMeters: 0, visibility: visibility.visibility(atElapsed: c.elapsedSeconds),
                                     category: c.line.category, name: name, summary: c.line.summary,
                                     kidSummary: c.line.kidSummary, spottingTip: nil))
        }
        return items.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
    }

    /// Items between now and `horizonSeconds` ahead, given the current schedule position.
    public func upcoming(fromElapsed elapsed: Double, horizonSeconds: Double = 1_800, userSide: CabinSide? = nil) -> [LookoutItem] {
        timeline(userSide: userSide).filter { $0.elapsedSeconds >= elapsed && $0.elapsedSeconds <= elapsed + horizonSeconds }
    }

    /// Items currently abeam (within a minute either way), nearest first.
    public func visibleNow(elapsed: Double, userSide: CabinSide? = nil, windowSeconds: Double = 90) -> [LookoutItem] {
        timeline(userSide: userSide)
            .filter { abs($0.elapsedSeconds - elapsed) <= windowSeconds }
            .sorted { $0.lateralDistanceMeters < $1.lateralDistanceMeters }
    }

    /// The best handful of highlights for the whole flight, for the pre-flight briefing.
    public func highlights(count: Int = 10, userSide: CabinSide? = nil) -> [LookoutItem] {
        let features = timeline(userSide: userSide).filter(\.isFeature)
        let ranked = features.sorted { a, b in
            guard case .feature(let fa) = a.kind, case .feature(let fb) = b.kind else { return false }
            return fa.salience > fb.salience
        }
        return Array(ranked.prefix(count)).sorted { $0.elapsedSeconds < $1.elapsedSeconds }
    }
}
