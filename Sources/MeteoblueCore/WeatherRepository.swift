import Foundation

public enum WeatherLoadSource: String, Codable, Equatable, Sendable {
    case network
    case freshCache
    case staleCache
    case lastKnownFallback
}

public struct WeatherLoadResult: Equatable, Sendable {
    public let snapshot: WeatherSnapshot
    public let source: WeatherLoadSource
    public let requestedLocation: WeatherLocation
    public let lastError: String?

    public init(snapshot: WeatherSnapshot, source: WeatherLoadSource, requestedLocation: WeatherLocation, lastError: String? = nil) {
        self.snapshot = snapshot
        self.source = source
        self.requestedLocation = requestedLocation
        self.lastError = lastError
    }

    public var isDifferentLocationFallback: Bool {
        snapshot.location.coordinate.distanceKilometers(to: requestedLocation.coordinate) > 20
    }
}

public actor WeatherRepository {
    private let service: any WeatherService
    private let cache: any WeatherCacheStore
    private let policy: WeatherCachePolicy

    public init(
        service: any WeatherService,
        cache: any WeatherCacheStore,
        policy: WeatherCachePolicy = WeatherCachePolicy()
    ) {
        self.service = service
        self.cache = cache
        self.policy = policy
    }

    public func weather(for location: WeatherLocation, at now: Date = Date(), forceRefresh: Bool = false) async throws -> WeatherLoadResult {
        let records = (try? await cache.loadRecords()) ?? []
        let match = policy.match(records: records, location: location, now: now)

        if !forceRefresh, case .fresh(let record, _) = match {
            return WeatherLoadResult(snapshot: record.snapshot, source: .freshCache, requestedLocation: location)
        }

        do {
            let snapshot = try await service.fetchWeather(for: location, at: now)
            let updated = policy.inserting(WeatherCacheRecord(snapshot: snapshot, storedAt: now), into: records)
            try? await cache.saveRecords(updated)
            return WeatherLoadResult(snapshot: snapshot, source: .network, requestedLocation: location)
        } catch {
            let message = Self.safeMessage(error)
            switch match {
            case .fresh(let record, _):
                return WeatherLoadResult(snapshot: record.snapshot, source: .freshCache, requestedLocation: location, lastError: message)
            case .stale(let record, _):
                return WeatherLoadResult(snapshot: record.snapshot, source: .staleCache, requestedLocation: location, lastError: message)
            case .none:
                if let latest = records.max(by: { $0.snapshot.fetchedAt < $1.snapshot.fetchedAt }) {
                    return WeatherLoadResult(snapshot: latest.snapshot, source: .lastKnownFallback, requestedLocation: location, lastError: message)
                }
                throw error
            }
        }
    }

    public func latestCachedWeather(at now: Date = Date()) async -> WeatherLoadResult? {
        let records = (try? await cache.loadRecords()) ?? []
        guard let latest = records.max(by: { $0.snapshot.fetchedAt < $1.snapshot.fetchedAt }) else { return nil }
        return WeatherLoadResult(
            snapshot: latest.snapshot,
            source: latest.snapshot.freshness(at: now, freshInterval: policy.freshInterval) == .fresh ? .freshCache : .staleCache,
            requestedLocation: latest.snapshot.location
        )
    }

    public func cachedWeatherNearest(to location: WeatherLocation, at now: Date = Date()) async -> WeatherLoadResult? {
        let records = (try? await cache.loadRecords()) ?? []
        switch policy.match(records: records, location: location, now: now) {
        case .fresh(let record, _): return WeatherLoadResult(snapshot: record.snapshot, source: .freshCache, requestedLocation: location)
        case .stale(let record, _): return WeatherLoadResult(snapshot: record.snapshot, source: .staleCache, requestedLocation: location)
        case .none:
            guard let latest = records.max(by: { $0.snapshot.fetchedAt < $1.snapshot.fetchedAt }) else { return nil }
            return WeatherLoadResult(snapshot: latest.snapshot, source: .lastKnownFallback, requestedLocation: location)
        }
    }

    private static func safeMessage(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "Erreur météo non détaillée."
    }
}
