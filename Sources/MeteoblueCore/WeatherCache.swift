import Foundation

public struct WeatherCacheRecord: Codable, Equatable, Sendable {
    public let snapshot: WeatherSnapshot
    public let storedAt: Date

    public init(snapshot: WeatherSnapshot, storedAt: Date? = nil) {
        self.snapshot = snapshot
        self.storedAt = storedAt ?? snapshot.fetchedAt
    }
}

public protocol WeatherCacheStore: Sendable {
    func loadRecords() async throws -> [WeatherCacheRecord]
    func saveRecords(_ records: [WeatherCacheRecord]) async throws
}

public actor JSONWeatherCacheStore: WeatherCacheStore {
    public enum StoreError: Error {
        case cannotCreateParentDirectory
    }

    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL) {
        self.url = url
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func loadRecords() async throws -> [WeatherCacheRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        if data.isEmpty { return [] }
        return try decoder.decode([WeatherCacheRecord].self, from: data)
    }

    public func saveRecords(_ records: [WeatherCacheRecord]) async throws {
        let parent = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        } catch {
            throw StoreError.cannotCreateParentDirectory
        }
        let data = try encoder.encode(records)
        let temporary = parent.appendingPathComponent("weather-cache-\(UUID().uuidString).tmp")
        try data.write(to: temporary, options: [.atomic])
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: url)
        }
    }
}

public struct WeatherCachePolicy: Sendable {
    public enum Match: Equatable, Sendable {
        case fresh(WeatherCacheRecord, distanceKilometers: Double)
        case stale(WeatherCacheRecord, distanceKilometers: Double)
        case none
    }

    public let freshInterval: TimeInterval
    public let locationThresholdKilometers: Double
    public let maximumRecords: Int

    public init(
        freshInterval: TimeInterval = 75 * 60,
        locationThresholdKilometers: Double = 20,
        maximumRecords: Int = 8
    ) {
        self.freshInterval = freshInterval
        self.locationThresholdKilometers = locationThresholdKilometers
        self.maximumRecords = max(1, maximumRecords)
    }

    public func match(records: [WeatherCacheRecord], location: WeatherLocation, now: Date) -> Match {
        guard location.coordinate.isValid else { return .none }
        let candidates = records.compactMap { record -> (WeatherCacheRecord, Double)? in
            let distance = record.snapshot.location.coordinate.distanceKilometers(to: location.coordinate)
            guard distance <= locationThresholdKilometers else { return nil }
            return (record, distance)
        }
        guard let nearest = candidates.min(by: { lhs, rhs in
            if abs(lhs.1 - rhs.1) > 0.001 { return lhs.1 < rhs.1 }
            return lhs.0.snapshot.fetchedAt > rhs.0.snapshot.fetchedAt
        }) else { return .none }

        let age = max(0, now.timeIntervalSince(nearest.0.snapshot.fetchedAt))
        if age <= freshInterval {
            return .fresh(nearest.0, distanceKilometers: nearest.1)
        }
        return .stale(nearest.0, distanceKilometers: nearest.1)
    }

    public func inserting(_ record: WeatherCacheRecord, into records: [WeatherCacheRecord]) -> [WeatherCacheRecord] {
        var result = records.filter {
            $0.snapshot.location.coordinate.distanceKilometers(to: record.snapshot.location.coordinate) > locationThresholdKilometers
        }
        result.append(record)
        result.sort { lhs, rhs in lhs.snapshot.fetchedAt > rhs.snapshot.fetchedAt }
        if result.count > maximumRecords {
            result.removeLast(result.count - maximumRecords)
        }
        return result
    }
}
