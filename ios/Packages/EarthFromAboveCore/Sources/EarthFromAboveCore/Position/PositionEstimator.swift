import Foundation

/// Where a position estimate came from, best first.
public enum PositionSource: String, Codable, Sendable, Comparable {
    case gps, airlineFeed, adsb, deadReckoning, none

    private var rank: Int {
        switch self {
        case .gps: return 4
        case .airlineFeed: return 3
        case .adsb: return 2
        case .deadReckoning: return 1
        case .none: return 0
        }
    }
    public static func < (a: PositionSource, b: PositionSource) -> Bool { a.rank < b.rank }

    public var displayName: String {
        switch self {
        case .gps: return "GPS"
        case .airlineFeed: return "Airline Wi-Fi"
        case .adsb: return "Flight tracking"
        case .deadReckoning: return "Estimated from schedule"
        case .none: return "Unknown"
        }
    }
}

/// A fix from any external source.
public struct PositionFix: Codable, Sendable {
    public var coordinate: Coordinate
    public var altitudeMeters: Double?
    public var trackDegrees: Double?
    public var groundSpeedMetersPerSecond: Double?
    public var horizontalAccuracyMeters: Double?
    public var time: Date
    public var source: PositionSource

    public init(coordinate: Coordinate, altitudeMeters: Double? = nil, trackDegrees: Double? = nil,
                groundSpeedMetersPerSecond: Double? = nil, horizontalAccuracyMeters: Double? = nil,
                time: Date, source: PositionSource) {
        self.coordinate = coordinate
        self.altitudeMeters = altitudeMeters
        self.trackDegrees = trackDegrees
        self.groundSpeedMetersPerSecond = groundSpeedMetersPerSecond
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.time = time
        self.source = source
    }
}

public struct PositionEstimate: Codable, Sendable {
    public var coordinate: Coordinate
    public var altitudeMeters: Double
    public var trackDegrees: Double
    public var groundSpeedMetersPerSecond: Double
    public var elapsedSeconds: Double
    public var source: PositionSource
    /// Rough 1-sigma horizontal uncertainty in metres.
    public var uncertaintyMeters: Double
    public var time: Date

    public var confidence: Confidence {
        switch uncertaintyMeters {
        case ..<2_000: return .high
        case ..<20_000: return .medium
        default: return .low
        }
    }

    public enum Confidence: String, Codable, Sendable { case high, medium, low }
}

/// Fuses GPS, external feeds and dead reckoning into one estimate.
///
/// Design: the route model gives a position for any elapsed time. Real fixes are
/// used directly while fresh, and extrapolated along their own track for a short
/// while. Every real fix also re-anchors dead reckoning by measuring how far ahead
/// or behind schedule the aircraft is, so the estimate degrades gracefully when
/// fixes stop arriving.
public struct PositionEstimator: Sendable {
    public var route: RouteModel?
    public private(set) var takeoffTime: Date?
    public private(set) var lastFix: PositionFix?
    /// Seconds to add to wall-clock elapsed time so the route position matches reality.
    public private(set) var scheduleOffsetSeconds: Double = 0

    public var gpsFreshnessSeconds: Double = 90
    public var feedFreshnessSeconds: Double = 180
    public var extrapolationLimitSeconds: Double = 600

    public init(route: RouteModel? = nil, takeoffTime: Date? = nil) {
        self.route = route
        self.takeoffTime = takeoffTime
    }

    public mutating func markTakeoff(at time: Date) {
        takeoffTime = time
        scheduleOffsetSeconds = 0
    }

    public mutating func clearTakeoff() { takeoffTime = nil }

    /// Accept a fix from any source. Lower-quality sources never displace a fresher,
    /// better one.
    public mutating func ingest(_ fix: PositionFix) {
        if let last = lastFix, last.source > fix.source,
           fix.time.timeIntervalSince(last.time) < gpsFreshnessSeconds {
            return
        }
        lastFix = fix
        if let route, let takeoffTime {
            let wallElapsed = fix.time.timeIntervalSince(takeoffTime)
            let match = route.elapsedTime(closestTo: fix.coordinate)
            // Only trust the re-anchor if the fix lies reasonably near the predicted track.
            if match.distanceMeters < 60_000 {
                scheduleOffsetSeconds = match.elapsed - wallElapsed
            }
        } else if let route, takeoffTime == nil, let spd = fix.groundSpeedMetersPerSecond, spd > 60 {
            // We are clearly airborne but the user never pressed the button: infer takeoff time.
            let match = route.elapsedTime(closestTo: fix.coordinate)
            if match.distanceMeters < 60_000 {
                takeoffTime = fix.time.addingTimeInterval(-match.elapsed)
            }
        }
    }

    public func estimate(at now: Date = Date()) -> PositionEstimate? {
        // 1. A fresh real fix, extrapolated along its own track.
        if let fix = lastFix {
            let age = now.timeIntervalSince(fix.time)
            let limit = fix.source == .gps ? gpsFreshnessSeconds : feedFreshnessSeconds
            if age >= 0 && age < extrapolationLimitSeconds {
                let routeSample = route.flatMap { r -> RouteSample? in
                    guard let t0 = takeoffTime else { return nil }
                    return r.sample(atElapsed: now.timeIntervalSince(t0) + scheduleOffsetSeconds)
                }
                let track = fix.trackDegrees ?? routeSample?.trackDegrees ?? 0
                let speed = fix.groundSpeedMetersPerSecond ?? routeSample?.groundSpeedMetersPerSecond ?? 0
                let coord = Geodesy.destination(from: fix.coordinate, bearingDegrees: track, distanceMeters: speed * age)
                let alt = fix.altitudeMeters ?? routeSample?.altitudeMeters ?? 10_000
                let baseUnc = fix.horizontalAccuracyMeters ?? (fix.source == .gps ? 50 : 1_000)
                // Uncertainty grows with extrapolation; faster once past the freshness window.
                let growth = age <= limit ? age * 15 : limit * 15 + (age - limit) * 60
                let elapsed = takeoffTime.map { now.timeIntervalSince($0) } ?? 0
                return PositionEstimate(coordinate: coord, altitudeMeters: alt, trackDegrees: track,
                                        groundSpeedMetersPerSecond: speed, elapsedSeconds: elapsed,
                                        source: fix.source, uncertaintyMeters: baseUnc + growth, time: now)
            }
        }
        // 2. Dead reckoning from the schedule.
        guard let route, let takeoffTime else { return nil }
        let elapsed = now.timeIntervalSince(takeoffTime)
        let s = route.sample(atElapsed: elapsed + scheduleOffsetSeconds)
        // Schedule error grows roughly with time since the last anchor; assume 2 percent of
        // distance flown plus a floor for lateral route deviation.
        let sinceAnchor = lastFix.map { now.timeIntervalSince($0.time) } ?? elapsed
        let unc = 15_000 + max(0, sinceAnchor) * s.groundSpeedMetersPerSecond * 0.02
        return PositionEstimate(coordinate: s.coordinate, altitudeMeters: s.altitudeMeters,
                                trackDegrees: s.trackDegrees, groundSpeedMetersPerSecond: s.groundSpeedMetersPerSecond,
                                elapsedSeconds: elapsed, source: .deadReckoning, uncertaintyMeters: unc, time: now)
    }

    /// Seconds of flight remaining according to the schedule and current anchor.
    public func remainingSeconds(at now: Date = Date()) -> Double? {
        guard let route, let takeoffTime else { return nil }
        return max(0, route.totalDurationSeconds - (now.timeIntervalSince(takeoffTime) + scheduleOffsetSeconds))
    }
}
