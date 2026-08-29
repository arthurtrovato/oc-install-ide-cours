import XCTest
@testable import MeteoblueCore

final class WeatherConsistencyTests: XCTestCase {
    private let now = utcDate("2026-08-25T08:00:00Z")

    func testFreshSnapshotInsideHyperlocalRadiusBeatsCloserStaleSnapshot() async throws {
        let staleExact = SampleWeatherFactory.make(
            locality: "Tressange stale",
            fetchedAt: utcDate("2026-08-25T07:30:00Z")
        )
        let nearbyCoordinate = GeoCoordinate(latitude: 49.410, longitude: 5.982)
        let freshNearby = SampleWeatherFactory.make(
            locality: "Tressange fresh",
            fetchedAt: utcDate("2026-08-25T07:50:00Z"),
            coordinate: nearbyCoordinate
        )
        let cache = InMemoryWeatherCacheStore(records: [
            WeatherCacheRecord(snapshot: staleExact),
            WeatherCacheRecord(snapshot: freshNearby)
        ])
        let counter = CountingWeatherService.Counter()
        let repository = WeatherRepository(
            service: CountingWeatherService(counter: counter, result: .failure(.transportFailure)),
            cache: cache
        )

        let result = try await repository.weather(for: staleExact.location, at: now)

        XCTAssertEqual(result.source, .freshCache)
        XCTAssertEqual(result.snapshot.fetchedAt, freshNearby.fetchedAt)
        XCTAssertEqual(result.snapshot.location.locality, "Tressange fresh")
        XCTAssertEqual(counter.read(), 0)
    }

    func testSameSnapshotProducesSameDailyRainAcrossPhoneAndWatchPresentationWindows() {
        let fetched = utcDate("2026-08-29T10:10:00Z")
        let snapshot = SampleWeatherFactory.make(locality: "Aumetz", fetchedAt: fetched)
        let phoneDate = utcDate("2026-08-29T10:19:00Z")
        let watchDate = utcDate("2026-08-29T11:05:00Z")

        let phone = WeatherTimelineBuilder(hourlyCount: 6).displayModel(snapshot: snapshot, at: phoneDate)
        let watch = WeatherTimelineBuilder(hourlyCount: 5).displayModel(snapshot: snapshot, at: watchDate)

        XCTAssertEqual(phone.todayPrecipitationSummary.totalMillimeters, watch.todayPrecipitationSummary.totalMillimeters)
        XCTAssertEqual(phone.todayPrecipitationSummary.timingAbbreviation, watch.todayPrecipitationSummary.timingAbbreviation)
        XCTAssertEqual(phone.todayPrecipitationSummary.timingDescription, watch.todayPrecipitationSummary.timingDescription)
        XCTAssertEqual(phone.snapshot.fetchedAt, watch.snapshot.fetchedAt)
    }

    func testDefaultSnapshotFreshnessMatchesSharedNinetyMinuteNetworkCadence() {
        let fetched = utcDate("2026-08-25T08:00:00Z")
        let snapshot = SampleWeatherFactory.make(fetchedAt: fetched)

        XCTAssertEqual(snapshot.freshness(at: fetched.addingTimeInterval(80 * 60)), .fresh)
        XCTAssertEqual(snapshot.freshness(at: fetched.addingTimeInterval(91 * 60)), .stale)
    }

    func testLoadDiagnosticIdentifiesExactSnapshotAndDisplayedRain() {
        let fetched = utcDate("2026-08-25T07:50:00Z")
        let snapshot = SampleWeatherFactory.make(locality: "Aumetz", fetchedAt: fetched)
        let result = WeatherLoadResult(
            snapshot: snapshot,
            source: .freshCache,
            requestedLocation: snapshot.location
        )
        let timeline = WeatherTimelineBuilder().build(snapshot: snapshot, from: now)
        let diagnostic = WeatherLoadDiagnostic(
            surface: "watch-widget",
            result: result,
            timeline: timeline,
            observedAt: now
        )

        XCTAssertEqual(diagnostic.source, .freshCache)
        XCTAssertEqual(diagnostic.fetchedAt, fetched)
        XCTAssertEqual(diagnostic.precipitationMillimeters, timeline.entries.first?.todayPrecipitationSummary.totalMillimeters)
        XCTAssertEqual(diagnostic.precipitationTiming, timeline.entries.first?.todayPrecipitationSummary.timingAbbreviation)
        XCTAssertEqual(diagnostic.firstVisibleHour, timeline.entries.first?.nextHours.first?.date)
        XCTAssertTrue(diagnostic.logLine.contains("METEOBLUE_SNAPSHOT"))
        XCTAssertTrue(diagnostic.logLine.contains("surface=watch-widget"))
        XCTAssertTrue(diagnostic.logLine.contains("source=freshCache"))
        XCTAssertTrue(diagnostic.logLine.contains("fetched_at="))
        XCTAssertTrue(diagnostic.logLine.contains("rain_mm="))
        XCTAssertTrue(diagnostic.logLine.contains("first_hour="))
    }
}
