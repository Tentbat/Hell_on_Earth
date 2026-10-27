import Foundation

public enum FlightPhase: String, Codable, Sendable {
    case preflight, climb, cruise, descent, landed

    public var displayName: String {
        switch self {
        case .preflight: return "On the ground"
        case .climb: return "Climbing"
        case .cruise: return "Cruising"
        case .descent: return "Descending"
        case .landed: return "Landed"
        }
    }
}

/// Detects flight phase from barometric altitude samples alone. Cabin pressure is
/// regulated, so the barometer reads cabin altitude, not true altitude. Cabin
/// altitude still climbs during climb, plateaus in cruise (typically 1800 to
/// 2400 m) and descends during descent, which is all we need here.
public struct FlightPhaseDetector: Sendable {
    public struct Sample: Sendable {
        public var cabinAltitudeMeters: Double
        public var time: Date
        public init(cabinAltitudeMeters: Double, time: Date) {
            self.cabinAltitudeMeters = cabinAltitudeMeters
            self.time = time
        }
    }

    public private(set) var phase: FlightPhase
    private var history: [Sample] = []
    private let windowSeconds: Double
    /// Vertical rate thresholds in metres per second of cabin altitude.
    private let climbThreshold: Double
    private let descentThreshold: Double

    public init(initialPhase: FlightPhase = .preflight,
                windowSeconds: Double = 90,
                climbThreshold: Double = 0.8,
                descentThreshold: Double = -0.8) {
        self.phase = initialPhase
        self.windowSeconds = windowSeconds
        self.climbThreshold = climbThreshold
        self.descentThreshold = descentThreshold
    }

    public mutating func markTakeoff() { phase = .climb }

    /// Feed a sample; returns the (possibly unchanged) phase.
    @discardableResult
    public mutating func add(_ s: Sample) -> FlightPhase {
        history.append(s)
        history.removeAll { s.time.timeIntervalSince($0.time) > windowSeconds }
        guard history.count >= 4, let first = history.first else { return phase }
        let dt = s.time.timeIntervalSince(first.time)
        guard dt > 20 else { return phase }
        let rate = (s.cabinAltitudeMeters - first.cabinAltitudeMeters) / dt

        switch phase {
        case .preflight:
            if rate > climbThreshold { phase = .climb }
        case .climb:
            if abs(rate) < climbThreshold * 0.4 && dt > 60 { phase = .cruise }
            else if rate < descentThreshold { phase = .descent }
        case .cruise:
            if rate < descentThreshold { phase = .descent }
            else if rate > climbThreshold { phase = .climb }   // step climb
        case .descent:
            if abs(rate) < 0.15 && dt > 60 && s.cabinAltitudeMeters < 2500 { phase = .landed }
            else if rate > climbThreshold { phase = .climb }   // go-around or step
        case .landed:
            if rate > climbThreshold { phase = .climb }
        }
        return phase
    }
}
