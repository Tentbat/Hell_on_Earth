import Foundation

/// Everything the app needs for one flight, downloaded before takeoff.
/// The backend builds it; the app stores it as JSON and reads it offline.
public struct RouteBundle: Codable, Sendable {
    public var formatVersion: Int
    public var flight: FlightInfo
    public var aircraft: AircraftInfo?
    public var route: RouteModel
    public var features: [Feature]
    public var lines: [LineFeature]
    public var clouds: [CloudSample]
    public var turbulence: [TurbulenceSample]
    public var generatedAt: Date
    /// Human-readable notes about what is in this bundle and data limitations.
    public var notes: [String]

    public init(formatVersion: Int = 1, flight: FlightInfo, aircraft: AircraftInfo? = nil, route: RouteModel,
                features: [Feature], lines: [LineFeature] = [], clouds: [CloudSample] = [],
                turbulence: [TurbulenceSample] = [], generatedAt: Date = Date(), notes: [String] = []) {
        self.formatVersion = formatVersion
        self.flight = flight
        self.aircraft = aircraft
        self.route = route
        self.features = features
        self.lines = lines
        self.clouds = clouds
        self.turbulence = turbulence
        self.generatedAt = generatedAt
        self.notes = notes
    }

    public static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
}

public struct FlightInfo: Codable, Sendable, Hashable {
    public var flightNumber: String
    public var airline: String?
    public var originCode: String
    public var originName: String
    public var destinationCode: String
    public var destinationName: String
    public var scheduledDeparture: Date?
    public var scheduledArrival: Date?
    public var originTimeZone: String?
    public var destinationTimeZone: String?

    public init(flightNumber: String, airline: String? = nil, originCode: String, originName: String,
                destinationCode: String, destinationName: String, scheduledDeparture: Date? = nil,
                scheduledArrival: Date? = nil, originTimeZone: String? = nil, destinationTimeZone: String? = nil) {
        self.flightNumber = flightNumber
        self.airline = airline
        self.originCode = originCode
        self.originName = originName
        self.destinationCode = destinationCode
        self.destinationName = destinationName
        self.scheduledDeparture = scheduledDeparture
        self.scheduledArrival = scheduledArrival
        self.originTimeZone = originTimeZone
        self.destinationTimeZone = destinationTimeZone
    }
}

public struct AircraftInfo: Codable, Sendable, Hashable {
    public var typeCode: String          // e.g. "B738"
    public var typeName: String          // e.g. "Boeing 737-800"
    public var registration: String?     // tail number
    public var manufacturedYear: Int?
    public var engines: String?
    public var seatLettersPerRow: Int?   // for side-of-plane from seat letter
    public var notes: String?            // "what is notable about this aircraft"
    public var typicalCruiseAltitudeMeters: Double?
    public var typicalCruiseSpeedMetersPerSecond: Double?

    public init(typeCode: String, typeName: String, registration: String? = nil, manufacturedYear: Int? = nil,
                engines: String? = nil, seatLettersPerRow: Int? = nil, notes: String? = nil,
                typicalCruiseAltitudeMeters: Double? = nil, typicalCruiseSpeedMetersPerSecond: Double? = nil) {
        self.typeCode = typeCode
        self.typeName = typeName
        self.registration = registration
        self.manufacturedYear = manufacturedYear
        self.engines = engines
        self.seatLettersPerRow = seatLettersPerRow
        self.notes = notes
        self.typicalCruiseAltitudeMeters = typicalCruiseAltitudeMeters
        self.typicalCruiseSpeedMetersPerSecond = typicalCruiseSpeedMetersPerSecond
    }
}
