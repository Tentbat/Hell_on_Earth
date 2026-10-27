import Foundation

/// The categories a feature can belong to and a user can express interest in.
/// The same taxonomy drives the interest checklist, the look-out list filter,
/// kid-mode bingo and the backend's feature pipeline.
public enum FeatureCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    // Geology
    case volcano, faultLine, crater, glacier, canyon, desert, saltFlat, karst, riverForm, mountain
    // Ecology
    case forest, wetland, reef, biomeTransition, wildfireScar, protectedArea
    // Water
    case lake, reservoirDam, river, coastline, estuary, seaIce
    // Human landscape
    case city, irrigation, agriculture, mine, windFarm, solarFarm, powerPlant, port, bridge, airport, highway, railway, border
    // History and culture
    case historicSite, battlefield, ghostTown, geoglyph, worldHeritage
    // Sky and atmosphere
    case cloud, contrail, opticalPhenomenon, sunriseSunset, aurora, lightning, cityLights, otherAircraft

    public var id: String { rawValue }

    public var group: InterestGroup {
        switch self {
        case .volcano, .faultLine, .crater, .glacier, .canyon, .desert, .saltFlat, .karst, .riverForm, .mountain: return .geology
        case .forest, .wetland, .reef, .biomeTransition, .wildfireScar, .protectedArea: return .ecology
        case .lake, .reservoirDam, .river, .coastline, .estuary, .seaIce: return .water
        case .city, .irrigation, .agriculture, .mine, .windFarm, .solarFarm, .powerPlant, .port, .bridge, .airport, .highway, .railway, .border: return .humanLandscape
        case .historicSite, .battlefield, .ghostTown, .geoglyph, .worldHeritage: return .history
        case .cloud, .contrail, .opticalPhenomenon, .sunriseSunset, .aurora, .lightning, .cityLights, .otherAircraft: return .sky
        }
    }

    public var displayName: String {
        switch self {
        case .volcano: return "Volcanoes"
        case .faultLine: return "Faults and plate boundaries"
        case .crater: return "Impact craters"
        case .glacier: return "Glaciers and glacial landforms"
        case .canyon: return "Canyons"
        case .desert: return "Deserts and dunes"
        case .saltFlat: return "Salt flats and playas"
        case .karst: return "Karst and sinkholes"
        case .riverForm: return "River forms: braids, meanders, deltas"
        case .mountain: return "Mountains and ranges"
        case .forest: return "Forests and deforestation fronts"
        case .wetland: return "Wetlands"
        case .reef: return "Coral reefs"
        case .biomeTransition: return "Biome transitions"
        case .wildfireScar: return "Wildfire scars"
        case .protectedArea: return "Parks and protected areas"
        case .lake: return "Lakes"
        case .reservoirDam: return "Reservoirs and dams"
        case .river: return "Rivers"
        case .coastline: return "Coastlines"
        case .estuary: return "Estuaries and bays"
        case .seaIce: return "Sea ice"
        case .city: return "Cities"
        case .irrigation: return "Irrigation patterns"
        case .agriculture: return "Farms and feedlots"
        case .mine: return "Mines and quarries"
        case .windFarm: return "Wind farms"
        case .solarFarm: return "Solar farms"
        case .powerPlant: return "Power plants"
        case .port: return "Ports and shipping"
        case .bridge: return "Bridges"
        case .airport: return "Airports"
        case .highway: return "Highways"
        case .railway: return "Railways"
        case .border: return "Borders and surveyed lines"
        case .historicSite: return "Ancient and historic sites"
        case .battlefield: return "Battlefields"
        case .ghostTown: return "Ghost towns"
        case .geoglyph: return "Geoglyphs and earthworks"
        case .worldHeritage: return "World Heritage sites"
        case .cloud: return "Cloud types"
        case .contrail: return "Contrails"
        case .opticalPhenomenon: return "Glories, halos and rainbows"
        case .sunriseSunset: return "Sunrise and sunset"
        case .aurora: return "Aurora"
        case .lightning: return "Lightning and storms"
        case .cityLights: return "City lights at night"
        case .otherAircraft: return "Other aircraft"
        }
    }

    /// Short label for kid mode.
    public var kidName: String {
        switch self {
        case .volcano: return "Volcano"
        case .faultLine: return "Crack in the Earth"
        case .crater: return "Space rock crater"
        case .glacier: return "Glacier"
        case .canyon: return "Canyon"
        case .desert: return "Desert"
        case .saltFlat: return "Salt flat"
        case .karst: return "Sinkholes"
        case .riverForm: return "Wiggly river"
        case .mountain: return "Mountains"
        case .forest: return "Forest"
        case .wetland: return "Swamp"
        case .reef: return "Coral reef"
        case .biomeTransition: return "Where the land changes"
        case .wildfireScar: return "Burned forest"
        case .protectedArea: return "National park"
        case .lake: return "Lake"
        case .reservoirDam: return "Dam"
        case .river: return "River"
        case .coastline: return "Beach and coast"
        case .estuary: return "Bay"
        case .seaIce: return "Sea ice"
        case .city: return "City"
        case .irrigation: return "Crop circles"
        case .agriculture: return "Farms"
        case .mine: return "Mine"
        case .windFarm: return "Windmills"
        case .solarFarm: return "Solar panels"
        case .powerPlant: return "Power station"
        case .port: return "Ships and harbour"
        case .bridge: return "Big bridge"
        case .airport: return "Airport"
        case .highway: return "Highway"
        case .railway: return "Train tracks"
        case .border: return "Border line"
        case .historicSite: return "Ancient place"
        case .battlefield: return "Battlefield"
        case .ghostTown: return "Ghost town"
        case .geoglyph: return "Giant drawing"
        case .worldHeritage: return "World treasure"
        case .cloud: return "Clouds"
        case .contrail: return "Plane trails"
        case .opticalPhenomenon: return "Rainbow ring"
        case .sunriseSunset: return "Sunset"
        case .aurora: return "Northern lights"
        case .lightning: return "Lightning"
        case .cityLights: return "City lights"
        case .otherAircraft: return "Other planes"
        }
    }
}

public enum InterestGroup: String, Codable, CaseIterable, Sendable, Identifiable {
    case geology, ecology, water, humanLandscape, history, sky
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .geology: return "Geology"
        case .ecology: return "Ecology and biomes"
        case .water: return "Water"
        case .humanLandscape: return "Human landscape"
        case .history: return "History and culture"
        case .sky: return "Sky and atmosphere"
        }
    }

    public var categories: [FeatureCategory] { FeatureCategory.allCases.filter { $0.group == self } }
}

/// The user's interest checklist. Empty means "everything".
public struct InterestProfile: Codable, Sendable, Equatable {
    public var selected: Set<FeatureCategory>

    public init(selected: Set<FeatureCategory> = []) { self.selected = selected }

    public static let everything = InterestProfile()

    public func includes(_ category: FeatureCategory) -> Bool {
        selected.isEmpty || selected.contains(category)
    }

    public mutating func toggle(_ category: FeatureCategory) {
        if selected.contains(category) { selected.remove(category) } else { selected.insert(category) }
    }

    public mutating func toggle(group: InterestGroup) {
        let cats = Set(group.categories)
        if cats.isSubset(of: selected) { selected.subtract(cats) } else { selected.formUnion(cats) }
    }
}
