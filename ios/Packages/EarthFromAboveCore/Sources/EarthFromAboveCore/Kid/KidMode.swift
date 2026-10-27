import Foundation

public enum KidBand: String, Codable, CaseIterable, Sendable, Identifiable {
    /// About 5 to 8, with a parent holding the phone.
    case explorer
    /// About 9 to 13, unsupervised.
    case navigator

    public var id: String { rawValue }
    public var displayName: String { self == .explorer ? "Explorer (ages 5 to 8)" : "Navigator (ages 9 to 13)" }
}

public struct BingoSquare: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var category: FeatureCategory
    public var featureID: String?
    public var elapsedSeconds: Double?
    public var found: Bool

    public init(id: String, title: String, category: FeatureCategory, featureID: String? = nil,
                elapsedSeconds: Double? = nil, found: Bool = false) {
        self.id = id
        self.title = title
        self.category = category
        self.featureID = featureID
        self.elapsedSeconds = elapsedSeconds
        self.found = found
    }
}

public enum KidMode {
    /// A 3x3 bingo card: up to six real features from the flight, spread across
    /// categories, plus generic sky squares that are always possible.
    public static func bingoCard(from items: [LookoutItem], userSide: CabinSide?) -> [BingoSquare] {
        var squares: [BingoSquare] = []
        var usedCategories = Set<FeatureCategory>()
        let features = items.filter(\.isFeature).sorted { a, b in
            guard case .feature(let fa) = a.kind, case .feature(let fb) = b.kind else { return false }
            return fa.salience > fb.salience
        }
        for item in features where squares.count < 6 {
            guard case .feature(let f) = item.kind else { continue }
            if usedCategories.contains(f.category) && squares.count >= 3 { continue }
            usedCategories.insert(f.category)
            squares.append(BingoSquare(id: "b-" + f.id, title: f.name,
                                       category: f.category, featureID: f.id, elapsedSeconds: item.elapsedSeconds))
        }
        let generic: [(String, FeatureCategory)] = [
            ("A fluffy cloud", .cloud), ("Another plane", .otherAircraft), ("A river", .river),
            ("Crop circles", .irrigation), ("A city", .city), ("A lake", .lake), ("A highway", .highway),
            ("Windmills", .windFarm), ("Mountains", .mountain)
        ]
        for g in generic where squares.count < 9 {
            if usedCategories.contains(g.1) { continue }
            squares.append(BingoSquare(id: "g-" + g.1.rawValue, title: g.0, category: g.1))
            usedCategories.insert(g.1)
        }
        return Array(squares.prefix(9))
    }

    /// Simplified sentence for a band. Explorer gets the kid summary or a stock line;
    /// Navigator gets the kid summary or the adult summary.
    public static func text(for item: LookoutItem, band: KidBand) -> String {
        switch band {
        case .explorer:
            return item.kidSummary ?? "Look for \(item.category.kidName.lowercased()) out the window!"
        case .navigator:
            return item.kidSummary ?? item.summary
        }
    }

    /// Mission briefing lines for the pre-flight screen.
    public static func briefing(flight: FlightInfo, items: [LookoutItem], band: KidBand) -> [String] {
        var lines: [String] = []
        lines.append("Your mission: fly from \(flight.originName) to \(flight.destinationName).")
        let features = items.filter(\.isFeature)
        lines.append("There are \(features.count) things to spot on this flight.")
        for item in features.prefix(band == .explorer ? 3 : 6) {
            let mins = Int(item.elapsedSeconds / 60)
            let sideText = item.side.map { $0 == .left ? "on the left" : "on the right" } ?? "right below you"
            lines.append("About \(mins) minutes after takeoff, look \(sideText): \(item.name).")
        }
        return lines
    }
}
