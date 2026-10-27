import Foundation
import EarthFromAboveCore

/// Saves route bundles as JSON in the app's Documents directory and loads the
/// built-in sample bundle from the app resources.
final class BundleStore {
    private let dir: URL

    init() {
        dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("bundles", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func id(for b: RouteBundle) -> String {
        let day = ISO8601DateFormatter().string(from: b.flight.scheduledDeparture ?? b.generatedAt).prefix(10)
        return "\(b.flight.flightNumber)-\(day)"
    }

    func save(_ b: RouteBundle) {
        guard let data = try? RouteBundle.encoder.encode(b) else { return }
        try? data.write(to: dir.appendingPathComponent(id(for: b) + ".json"), options: .atomic)
    }

    func load(id: String) -> RouteBundle? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(id + ".json")) else { return nil }
        return try? RouteBundle.decoder.decode(RouteBundle.self, from: data)
    }

    func list() -> [RouteBundle] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { url in
            guard url.pathExtension == "json", let data = try? Data(contentsOf: url) else { return nil }
            return try? RouteBundle.decoder.decode(RouteBundle.self, from: data)
        }.sorted { $0.generatedAt > $1.generatedAt }
    }

    func delete(id: String) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(id + ".json"))
    }

    enum StoreError: LocalizedError {
        case sampleMissing
        var errorDescription: String? { "The sample bundle is missing from the app resources." }
    }

    func loadSample() throws -> RouteBundle {
        guard let url = Bundle.main.url(forResource: "SampleBundle", withExtension: "json") else { throw StoreError.sampleMissing }
        let data = try Data(contentsOf: url)
        return try RouteBundle.decoder.decode(RouteBundle.self, from: data)
    }
}
