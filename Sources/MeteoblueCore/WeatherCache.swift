import Foundation

public struct WeatherRefreshCadence: Equatable, Sendable {
    public static let defaultInterval: TimeInterval = 90 * 60
    public static let defaultPhase: TimeInterval = 5 * 60

    public let interval: TimeInterval
    public let phase: TimeInterval

    public init(
        interval: TimeInterval = WeatherRefreshCadence.defaultInterval,
        phase: TimeInterval = WeatherRefreshCadence.defaultPhase
    ) {
        self.interval = max(15 * 60, interval)
        let normalized = phase.truncatingRemainder(dividingBy: self.interval)
        self.phase = normalized >= 0 ? normalized : normalized + self.interval
    }

    public func bucketStart(containing date: Date) -> Date {
        let shifted = date.timeIntervalSince1970 - phase
        let bucket = floor(shifted / interval)
        return Date(timeIntervalSince1970: bucket * interval + phase)
    }

    public func nextBoundary(after date: Date) -> Date {
        bucketStart(containing: date).addingTimeInterval(interval)
    }

    public func contains(fetchedAt: Date, at now: Date) -> Bool {
        fetchedAt >= bucketStart(containing: now) && fetchedAt <= now.addingTimeInterval(5 * 60)
    }
}

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
    public static let defaultLocationThresholdKilometers = 2.0

    public enum Match: Equatable, Sendable {
        case fresh(WeatherCacheRecord, distanceKilometers: Double)
        case stale(WeatherCacheRecord, distanceKilometers: Double)
        case none
    }

    public let freshInterval: TimeInterval
    public let locationThresholdKilometers: Double
    public let maximumRecords: Int
    public let refreshCadence: WeatherRefreshCadence

    public init(
        freshInterval: TimeInterval = WeatherRefreshCadence.defaultInterval,
        locationThresholdKilometers: Double = WeatherCachePolicy.defaultLocationThresholdKilometers,
        maximumRecords: Int = 8,
        refreshCadence: WeatherRefreshCadence = WeatherRefreshCadence()
    ) {
        self.freshInterval = max(15 * 60, freshInterval)
        self.locationThresholdKilometers = max(0.1, locationThresholdKilometers)
        self.maximumRecords = max(1, maximumRecords)
        self.refreshCadence = refreshCadence
    }

    public func match(records: [WeatherCacheRecord], location: WeatherLocation, now: Date) -> Match {
        guard location.coordinate.isValid else { return .none }
        let candidates = records.compactMap { record -> (record: WeatherCacheRecord, distance: Double)? in
            let distance = record.snapshot.location.coordinate.distanceKilometers(to: location.coordinate)
            guard distance <= locationThresholdKilometers else { return nil }
            return (record, distance)
        }
        guard !candidates.isEmpty else { return .none }

        func closest(_ values: [(record: WeatherCacheRecord, distance: Double)]) -> (record: WeatherCacheRecord, distance: Double)? {
            values.min { lhs, rhs in
                if abs(lhs.distance - rhs.distance) > 0.001 { return lhs.distance < rhs.distance }
                return lhs.record.snapshot.fetchedAt > rhs.record.snapshot.fetchedAt
            }
        }

        // Prefer any snapshot that is still valid for the shared refresh window before
        // falling back to a geographically closer but stale record. Every candidate is
        // already inside the 2 km hyperlocal tolerance, so this avoids an unnecessary
        // network call without accepting a meaningfully different weather zone.
        let freshCandidates = candidates.filter { candidate in
            let age = max(0, now.timeIntervalSince(candidate.record.snapshot.fetchedAt))
            return age <= freshInterval && refreshCadence.contains(fetchedAt: candidate.record.snapshot.fetchedAt, at: now)
        }
        if let fresh = closest(freshCandidates) {
            return .fresh(fresh.record, distanceKilometers: fresh.distance)
        }

        guard let nearest = closest(candidates) else { return .none }
        return .stale(nearest.record, distanceKilometers: nearest.distance)
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
