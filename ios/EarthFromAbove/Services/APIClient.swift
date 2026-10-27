import Foundation
import UIKit
import EarthFromAboveCore

/// Talks to the Earth from Above backend. Every call is optional: the app works
/// offline from the bundle, and these calls add live data and richer explanations.
struct APIClient {
    static let freeExplanationsPerFlight = 3

    var baseURL: URL
    var session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    static func resolveBaseURL(override: String) -> URL {
        if let u = URL(string: override), !override.isEmpty { return u }
        if let s = Bundle.main.object(forInfoDictionaryKey: "EFA_BACKEND_URL") as? String, let u = URL(string: s) { return u }
        return URL(string: "http://localhost:8000")!
    }

    enum APIError: LocalizedError {
        case http(Int, String)
        case offline
        var errorDescription: String? {
            switch self {
            case .http(let code, let msg): return "Server error \(code): \(msg)"
            case .offline: return "No connection."
            }
        }
    }

    private func request(_ path: String, query: [String: String] = [:], method: String = "GET", body: Data? = nil) async throws -> Data {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.httpBody = body
        if body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        req.setValue(DeviceIdentity.id, forHTTPHeaderField: "X-Device-Id")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.offline }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    // MARK: Flights and bundles

    struct FlightSearchResult: Codable, Identifiable {
        var flightNumber: String
        var airline: String?
        var originCode: String
        var destinationCode: String
        var scheduledDeparture: Date?
        var id: String { flightNumber + (scheduledDeparture.map { ISO8601DateFormatter().string(from: $0) } ?? "") }
    }

    func searchFlights(number: String, date: Date) async throws -> [FlightSearchResult] {
        let day = ISO8601DateFormatter().string(from: date).prefix(10)
        let data = try await request("v1/flights/search", query: ["flight": number, "date": String(day)])
        return try RouteBundle.decoder.decode([FlightSearchResult].self, from: data)
    }

    func fetchBundle(flightNumber: String, date: Date) async throws -> RouteBundle {
        let day = ISO8601DateFormatter().string(from: date).prefix(10)
        let data = try await request("v1/bundles", query: ["flight": flightNumber, "date": String(day)])
        return try RouteBundle.decoder.decode(RouteBundle.self, from: data)
    }

    // MARK: Live position for our own flight (needs internet via in-flight Wi-Fi)

    struct LivePosition: Codable {
        var latitude: Double
        var longitude: Double
        var altitudeMeters: Double?
        var trackDegrees: Double?
        var groundSpeedMetersPerSecond: Double?
        var time: Date
    }

    func livePosition(flightNumber: String) async throws -> PositionFix {
        let data = try await request("v1/flights/\(flightNumber)/live")
        let p = try RouteBundle.decoder.decode(LivePosition.self, from: data)
        return PositionFix(coordinate: Coordinate(latitude: p.latitude, longitude: p.longitude), altitudeMeters: p.altitudeMeters,
                           trackDegrees: p.trackDegrees, groundSpeedMetersPerSecond: p.groundSpeedMetersPerSecond,
                           horizontalAccuracyMeters: 1_000, time: p.time, source: .adsb)
    }

    // MARK: Photo explanation

    struct ExplainRequest: Codable {
        var imageBase64: String
        var mediaType: String
        var pose: CameraPose
        var elapsedSeconds: Double
        var flightNumber: String
        var candidates: [String]        // feature IDs, best first
        var kidBand: KidBand?
        var question: String?
    }

    struct ExplainResponse: Codable {
        var title: String
        var explanation: String
        var matchedFeatureID: String?
        var confidence: String
        var followUps: [String]
        var model: String?
    }

    func explain(image: UIImage, pose: CameraPose, elapsedSeconds: Double, flightNumber: String,
                 candidates: [PhotoCandidate], kidBand: KidBand?, question: String?) async throws -> ExplainResponse {
        let resized = image.resized(maxDimension: 1_568)
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { throw APIError.offline }
        let body = ExplainRequest(imageBase64: jpeg.base64EncodedString(), mediaType: "image/jpeg", pose: pose,
                                  elapsedSeconds: elapsedSeconds, flightNumber: flightNumber,
                                  candidates: candidates.map(\.id), kidBand: kidBand, question: question)
        let data = try await request("v1/explain", method: "POST", body: try RouteBundle.encoder.encode(body))
        return try RouteBundle.decoder.decode(ExplainResponse.self, from: data)
    }

    // MARK: Shared sightings (friends and family)

    struct Sighting: Codable, Identifiable {
        var id: String
        var featureID: String?
        var title: String
        var note: String?
        var latitude: Double
        var longitude: Double
        var elapsedSeconds: Double
        var flightNumber: String
        var createdAt: Date
        var imageURL: String?
    }

    func postSighting(circleCode: String, title: String, note: String?, feature: Feature?, estimate: PositionEstimate,
                      flightNumber: String, image: UIImage?) async throws -> Sighting {
        struct Body: Codable {
            var circleCode: String; var title: String; var note: String?; var featureID: String?
            var latitude: Double; var longitude: Double; var elapsedSeconds: Double; var flightNumber: String
            var imageBase64: String?
        }
        let b = Body(circleCode: circleCode, title: title, note: note, featureID: feature?.id,
                     latitude: estimate.coordinate.latitude, longitude: estimate.coordinate.longitude,
                     elapsedSeconds: estimate.elapsedSeconds, flightNumber: flightNumber,
                     imageBase64: image?.resized(maxDimension: 1_200).jpegData(compressionQuality: 0.75)?.base64EncodedString())
        let data = try await request("v1/sightings", method: "POST", body: try RouteBundle.encoder.encode(b))
        return try RouteBundle.decoder.decode(Sighting.self, from: data)
    }

    func sightings(circleCode: String) async throws -> [Sighting] {
        let data = try await request("v1/sightings", query: ["circle": circleCode])
        return try RouteBundle.decoder.decode([Sighting].self, from: data)
    }
}

enum DeviceIdentity {
    static var id: String {
        let key = "efa.device.id"
        if let s = UserDefaults.standard.string(forKey: key) { return s }
        let s = UUID().uuidString
        UserDefaults.standard.set(s, forKey: key)
        return s
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
