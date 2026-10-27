import Foundation
import EarthFromAboveCore

/// Persisted user settings. Small enough for UserDefaults as JSON.
struct UserSettings: Codable, Equatable {
    var seat: String = ""
    var side: CabinSide? = nil
    var interests: InterestProfile = .everything
    var kidModeEnabled: Bool = false
    var kidBand: KidBand = .navigator
    var kidOnlineExplanationsAllowed: Bool = false
    var notificationsEnabled: Bool = true
    var notificationLeadSeconds: Double = 300
    var useMetric: Bool = false
    var backendURL: String = ""
    /// Free-tier quota for online explanations per flight. Entitlements come from the backend later.
    var onlineExplanationsUsedThisFlight: Int = 0
    var isPremium: Bool = false

    static let storageKey = "efa.settings.v1"

    static func load() -> UserSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let s = try? JSONDecoder().decode(UserSettings.self, from: data) else { return UserSettings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.storageKey) }
    }
}

/// State of the current flight that must survive the app being killed mid-flight.
struct FlightSession: Codable, Equatable {
    var bundleID: String
    var takeoffTime: Date?
    var foundBingoSquares: Set<String> = []
    var checkedLookoutItems: Set<String> = []

    static let storageKey = "efa.session.v1"

    static func load() -> FlightSession? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(FlightSession.self, from: data)
    }
    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.storageKey) }
    }
    static func clear() { UserDefaults.standard.removeObject(forKey: storageKey) }
}
