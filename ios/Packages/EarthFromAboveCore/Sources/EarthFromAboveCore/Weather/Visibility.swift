import Foundation

/// Cloud cover sampled along the route, from satellite imagery or a forecast grid.
public struct CloudSample: Codable, Sendable {
    public var elapsedSeconds: Double
    /// 0...1 fraction of sky (as seen from above, fraction of ground hidden).
    public var cloudFraction: Double
    /// Approximate cloud top height in metres, if known. Cloud above the aircraft
    /// hides the sky, cloud below hides the ground.
    public var cloudTopMeters: Double?

    public init(elapsedSeconds: Double, cloudFraction: Double, cloudTopMeters: Double? = nil) {
        self.elapsedSeconds = elapsedSeconds
        self.cloudFraction = cloudFraction
        self.cloudTopMeters = cloudTopMeters
    }
}

public enum GroundVisibility: String, Codable, Sendable {
    case clear, partial, obscured, unknown

    public var displayName: String {
        switch self {
        case .clear: return "Clear view"
        case .partial: return "Partly cloudy below"
        case .obscured: return "Under cloud"
        case .unknown: return "No cloud data"
        }
    }
}

public struct VisibilityModel: Codable, Sendable {
    public var samples: [CloudSample]

    public init(samples: [CloudSample]) { self.samples = samples.sorted { $0.elapsedSeconds < $1.elapsedSeconds } }

    public func cloudFraction(atElapsed t: Double) -> Double? {
        guard let first = samples.first, let last = samples.last else { return nil }
        if t <= first.elapsedSeconds { return first.cloudFraction }
        if t >= last.elapsedSeconds { return last.cloudFraction }
        for (a, b) in zip(samples, samples.dropFirst()) where t >= a.elapsedSeconds && t <= b.elapsedSeconds {
            let f = (t - a.elapsedSeconds) / max(1e-6, b.elapsedSeconds - a.elapsedSeconds)
            return a.cloudFraction + (b.cloudFraction - a.cloudFraction) * f
        }
        return nil
    }

    public func visibility(atElapsed t: Double) -> GroundVisibility {
        guard let f = cloudFraction(atElapsed: t) else { return .unknown }
        switch f {
        case ..<0.3: return .clear
        case ..<0.7: return .partial
        default: return .obscured
        }
    }

    /// Contiguous windows of the flight with the same visibility class.
    public func windows(totalDurationSeconds: Double, stepSeconds: Double = 120) -> [(start: Double, end: Double, visibility: GroundVisibility)] {
        var out: [(Double, Double, GroundVisibility)] = []
        var t = 0.0
        var current: (Double, GroundVisibility)? = nil
        while t <= totalDurationSeconds {
            let v = visibility(atElapsed: t)
            if let c = current {
                if c.1 != v { out.append((c.0, t, c.1)); current = (t, v) }
            } else { current = (t, v) }
            t += stepSeconds
        }
        if let c = current { out.append((c.0, totalDurationSeconds, c.1)) }
        return out.map { (start: $0.0, end: $0.1, visibility: $0.2) }
    }
}

/// Turbulence outlook along the route, from forecast grids and pilot reports.
public struct TurbulenceSample: Codable, Sendable {
    public enum Level: String, Codable, Sendable, Comparable {
        case smooth, light, moderate, severe
        private var rank: Int { ["smooth": 0, "light": 1, "moderate": 2, "severe": 3][rawValue]! }
        public static func < (a: Level, b: Level) -> Bool { a.rank < b.rank }

        public var displayName: String { rawValue.capitalized }
        public var seatbeltLikely: Bool { self >= .moderate }
    }
    public enum Cause: String, Codable, Sendable {
        case jetStream, mountainWave, convection, clearAir, lowLevel, unknown
        public var explanation: String {
            switch self {
            case .jetStream: return "Wind shear at the edge of the jet stream, a river of fast air at cruise height."
            case .mountainWave: return "Air flowing over mountains sets up waves that can extend far downwind and well above the peaks."
            case .convection: return "Rising air in and around thunderstorms. Pilots route around the storms; the edges can still be bumpy."
            case .clearAir: return "Clear-air turbulence from wind shear with no cloud to show it, which is why the seatbelt sign can come on in blue sky."
            case .lowLevel: return "Thermals and wind over terrain near the ground, mostly on climb and approach."
            case .unknown: return "Cause not identified."
            }
        }
    }
    public var elapsedSeconds: Double
    public var level: Level
    public var cause: Cause

    public init(elapsedSeconds: Double, level: Level, cause: Cause) {
        self.elapsedSeconds = elapsedSeconds
        self.level = level
        self.cause = cause
    }
}
