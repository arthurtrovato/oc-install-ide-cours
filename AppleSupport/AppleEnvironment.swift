import Foundation
import MeteoblueCore

struct AppleConfiguration: Sendable {
    let meteoblueAPIKey: String?

    var isConfigured: Bool {
        guard let key = meteoblueAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else { return false }
        let upper = key.uppercased()
        return !upper.contains("YOUR_") && !upper.contains("PLACEHOLDER") && !upper.contains("UNCONFIGURED")
    }

    static func fromMainBundle() -> AppleConfiguration {
        let raw = Bundle.main.object(forInfoDictionaryKey: "MeteoblueAPIKey") as? String
        return AppleConfiguration(meteoblueAPIKey: raw)
    }
}

struct AppleEnvironment: Sendable {
    let configuration: AppleConfiguration
    let cacheStore: JSONWeatherCacheStore
    let locationStore: FileLocationStore

    static func make(namespace: String) -> AppleEnvironment {
        let base = applicationSupportDirectory().appendingPathComponent("MeteoblueWeather", isDirectory: true)
        let scoped = base.appendingPathComponent(namespace, isDirectory: true)
        return AppleEnvironment(
            configuration: .fromMainBundle(),
            cacheStore: JSONWeatherCacheStore(url: scoped.appendingPathComponent("weather-cache.json")),
            locationStore: FileLocationStore(url: scoped.appendingPathComponent("last-location.json"))
        )
    }

    private static func applicationSupportDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }
}

actor FileLocationStore {
    private let url: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(url: URL) {
        self.url = url
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> LocationSample? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(LocationSample.self, from: data)
    }

    func save(_ sample: LocationSample) {
        do {
            let parent = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
            try encoder.encode(sample).write(to: url, options: [.atomic])
        } catch {
            // Location persistence is best-effort; weather cache remains independent.
        }
    }
}
