import XCTest
@testable import MeteoblueCore

final class WeatherCacheRepositoryTests: XCTestCase {
    let now = utcDate("2026-08-25T08:00:00Z")

    func testCacheAbsentCallsNetworkAndStoresResult() async throws {
        let snapshot = SampleWeatherFactory.make(fetchedAt: now)
        let counter = CountingWeatherService.Counter()
        let service = CountingWeatherService(counter: counter, result: .success(snapshot))
        let cache = InMemoryWeatherCacheStore()
        let repository = WeatherRepository(service: service, cache: cache)

        let result = try await repository.weather(for: snapshot.location, at: now)
        XCTAssertEqual(result.source, .network)
        XCTAssertEqual(counter.read(), 1)
        let stored = try await cache.loadRecords()
        XCTAssertEqual(stored.count, 1)
    }

    func testFreshCacheInCurrentAlignedWindowAvoidsNetwork() async throws {
        let snapshot = SampleWeatherFactory.make(fetchedAt: utcDate("2026-08-25T07:50:00Z"))
        let cache = InMemoryWeatherCacheStore(records: [WeatherCacheRecord(snapshot: snapshot)])
        let counter = CountingWeatherService.Counter()
        let service = CountingWeatherService(counter: counter, result: .failure(.transportFailure))
        let result = try await WeatherRepository(service: service, cache: cache).weather(for: snapshot.location, at: now)
        XCTAssertEqual(result.source, .freshCache)
        XCTAssertEqual(counter.read(), 0)
    }

    func testPreviousAlignedWindowRefreshesEvenWhenRollingAgeIsShort() async throws {
        let previousWindow = SampleWeatherFactory.make(fetchedAt: utcDate("2026-08-25T07:30:00Z"))
        let fresh = SampleWeatherFactory.make(condition: .clear, fetchedAt: now)
        let cache = InMemoryWeatherCacheStore(records: [WeatherCacheRecord(snapshot: previousWindow)])
        let counter = CountingWeatherService.Counter()
        let result = try await WeatherRepository(
            service: CountingWeatherService(counter: counter, result: .success(fresh)),
            cache: cache
        ).weather(for: fresh.location, at: now)
        XCTAssertEqual(result.source, .network)
        XCTAssertEqual(counter.read(), 1)
        XCTAssertEqual(result.snapshot.current.condition, .clear)
    }

    func testExpiredCacheRefreshesFromNetwork() async throws {
        let stale = SampleWeatherFactory.make(fetchedAt: now.addingTimeInterval(-2 * 60 * 60))
        let fresh = SampleWeatherFactory.make(condition: .clear, fetchedAt: now)
        let cache = InMemoryWeatherCacheStore(records: [WeatherCacheRecord(snapshot: stale)])
        let counter = CountingWeatherService.Counter()
        let service = CountingWeatherService(counter: counter, result: .success(fresh))
        let result = try await WeatherRepository(service: service, cache: cache).weather(for: fresh.location, at: now)
        XCTAssertEqual(result.source, .network)
        XCTAssertEqual(result.snapshot.current.condition, .clear)
        XCTAssertEqual(counter.read(), 1)
    }

    func testOfflineReturnsStaleCacheRatherThanBlank() async throws {
        let stale = SampleWeatherFactory.make(fetchedAt: now.addingTimeInterval(-3 * 60 * 60))
        let cache = InMemoryWeatherCacheStore(records: [WeatherCacheRecord(snapshot: stale)])
        let service = CountingWeatherService(counter: .init(), result: .failure(.transportFailure))
        let result = try await WeatherRepository(service: service, cache: cache).weather(for: stale.location, at: now)
        XCTAssertEqual(result.source, .staleCache)
        XCTAssertNotNil(result.lastError)
        XCTAssertEqual(result.snapshot, stale)
    }

    func testAPIErrorWithoutCacheIsPropagated() async {
        let snapshot = SampleWeatherFactory.make(fetchedAt: now)
        let repository = WeatherRepository(
            service: CountingWeatherService(counter: .init(), result: .failure(.httpStatus(429))),
            cache: InMemoryWeatherCacheStore()
        )
        do {
            _ = try await repository.weather(for: snapshot.location, at: now)
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? WeatherServiceError, .httpStatus(429))
        }
    }

    func testMoveBeyondTwoKilometersForcesNetworkEvenWhenOldCacheFresh() async throws {
        let old = SampleWeatherFactory.make(fetchedAt: utcDate("2026-08-25T07:50:00Z"))
        let movedLocation = WeatherLocation(
            coordinate: GeoCoordinate(latitude: 49.410, longitude: 5.950),
            locality: "Aumetz",
            countryCode: "FR",
            timeZoneIdentifier: "Europe/Paris"
        )
        let moved = WeatherSnapshot(
            fetchedAt: now,
            location: movedLocation,
            current: old.current,
            hourly: old.hourly,
            daily: old.daily,
            meteoblueURL: try! MeteoblueForecastLinkBuilder.webURL(for: movedLocation)
        )
        let counter = CountingWeatherService.Counter()
        let result = try await WeatherRepository(
            service: CountingWeatherService(counter: counter, result: .success(moved)),
            cache: InMemoryWeatherCacheStore(records: [WeatherCacheRecord(snapshot: old)])
        ).weather(for: movedLocation, at: now)
        XCTAssertEqual(result.source, .network)
        XCTAssertEqual(counter.read(), 1)
        XCTAssertEqual(result.snapshot.location.locality, "Aumetz")
    }

    func testOfflineAtNewPositionFallsBackToLastKnownData() async throws {
        let old = SampleWeatherFactory.make(fetchedAt: utcDate("2026-08-25T07:50:00Z"))
        let parisLocation = WeatherLocation(
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522),
            locality: "Paris",
            countryCode: "FR",
            timeZoneIdentifier: "Europe/Paris"
        )
        let result = try await WeatherRepository(
            service: CountingWeatherService(counter: .init(), result: .failure(.transportFailure)),
            cache: InMemoryWeatherCacheStore(records: [WeatherCacheRecord(snapshot: old)])
        ).weather(for: parisLocation, at: now)
        XCTAssertEqual(result.source, .lastKnownFallback)
        XCTAssertTrue(result.isDifferentLocationFallback)
    }

    func testReturnToPreviousZoneReusesItsFreshCache() async throws {
        let tressange = SampleWeatherFactory.make(fetchedAt: utcDate("2026-08-25T07:50:00Z"))
        let parisLocation = WeatherLocation(coordinate: .init(latitude: 48.8566, longitude: 2.3522), locality: "Paris", countryCode: "FR", timeZoneIdentifier: "Europe/Paris")
        let paris = WeatherSnapshot(fetchedAt: utcDate("2026-08-25T07:50:00Z"), location: parisLocation, current: tressange.current, hourly: tressange.hourly, daily: tressange.daily, meteoblueURL: try! MeteoblueForecastLinkBuilder.webURL(for: parisLocation))
        let cache = InMemoryWeatherCacheStore(records: [WeatherCacheRecord(snapshot: tressange), WeatherCacheRecord(snapshot: paris)])
        let counter = CountingWeatherService.Counter()
        let result = try await WeatherRepository(
            service: CountingWeatherService(counter: counter, result: .failure(.transportFailure)),
            cache: cache
        ).weather(for: tressange.location, at: now)
        XCTAssertEqual(result.source, .freshCache)
        XCTAssertEqual(result.snapshot.location.locality, "Tressange")
        XCTAssertEqual(counter.read(), 0)
    }

    func testVeryOldCacheStillSurvivesOffline() async throws {
        let old = SampleWeatherFactory.make(fetchedAt: now.addingTimeInterval(-2 * 24 * 60 * 60))
        let result = try await WeatherRepository(
            service: CountingWeatherService(counter: .init(), result: .failure(.transportFailure)),
            cache: InMemoryWeatherCacheStore(records: [WeatherCacheRecord(snapshot: old)])
        ).weather(for: old.location, at: now)
        XCTAssertEqual(result.source, .staleCache)
        XCTAssertEqual(result.snapshot.freshness(at: now), .veryStale)
    }
}
