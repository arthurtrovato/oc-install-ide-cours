import XCTest
@testable import MeteoblueCore

final class WeatherTimelineTests: XCTestCase {
    func testDisplayContainsSixHoursAndFiveDays() {
        let now = utcDate("2026-08-25T08:00:00Z")
        let model = WeatherTimelineBuilder().displayModel(snapshot: SampleWeatherFactory.make(fetchedAt: now), at: now)
        XCTAssertEqual(model.nextHours.count, 6)
        XCTAssertEqual(model.nextDays.count, 5)
        XCTAssertEqual(model.todayPrecipitationMillimeters, 1.4)
    }

    func testFutureEntriesIncludeHourlyBoundaryAndFiveMinuteCutoverWithoutNetworkFetch() {
        let now = utcDate("2026-08-25T08:10:00Z")
        let snapshot = SampleWeatherFactory.make(fetchedAt: now)
        let timeline = WeatherTimelineBuilder().build(snapshot: snapshot, from: now)
        XCTAssertEqual(timeline.entries.count, 15)
        XCTAssertEqual(timeline.entries[1].date, utcDate("2026-08-25T09:00:00Z"))
        XCTAssertEqual(timeline.entries[2].date, utcDate("2026-08-25T09:05:00Z"))
        XCTAssertNotEqual(timeline.entries[1].nextHours.first?.date, timeline.entries[2].nextHours.first?.date)
        XCTAssertEqual(timeline.entries[2].snapshot.fetchedAt, snapshot.fetchedAt)
    }

    func testFiveMinuteCutoverMakesIndependentlyGeneratedTimelinesAgreeOnHourlyWindow() {
        let snapshot = SampleWeatherFactory.make(fetchedAt: utcDate("2026-08-25T08:00:00Z"))
        let builder = WeatherTimelineBuilder()
        let atBoundary = builder.displayModel(snapshot: snapshot, at: utcDate("2026-08-25T09:00:00Z"))
        let afterCutover = builder.displayModel(snapshot: snapshot, at: utcDate("2026-08-25T09:05:00Z"))
        XCTAssertEqual(atBoundary.nextHours.first?.date, utcDate("2026-08-25T09:00:00Z"))
        XCTAssertEqual(afterCutover.nextHours.first?.date, utcDate("2026-08-25T10:00:00Z"))
    }

    func testMidnightChangesDailyWindow() {
        let snapshot = SampleWeatherFactory.make(fetchedAt: localDate("2026-08-25 22:00"))
        let before = WeatherTimelineBuilder().displayModel(snapshot: snapshot, at: localDate("2026-08-25 23:55"))
        let after = WeatherTimelineBuilder().displayModel(snapshot: snapshot, at: localDate("2026-08-26 00:05"))
        XCTAssertNotEqual(before.nextDays.first?.date, after.nextDays.first?.date)
    }

    func testTimezoneAffectsDayBoundary() {
        let instant = utcDate("2026-08-26T02:30:00Z")
        let paris = SampleWeatherFactory.make(fetchedAt: instant, zone: "Europe/Paris")
        let newYork = SampleWeatherFactory.make(locality: "New York", fetchedAt: instant, zone: "America/New_York", coordinate: .init(latitude: 40.7128, longitude: -74.0060))
        let parisModel = WeatherTimelineBuilder().displayModel(snapshot: paris, at: instant)
        let nyModel = WeatherTimelineBuilder().displayModel(snapshot: newYork, at: instant)
        var parisCalendar = Calendar(identifier: .gregorian)
        parisCalendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        var nyCalendar = Calendar(identifier: .gregorian)
        nyCalendar.timeZone = TimeZone(identifier: "America/New_York")!
        XCTAssertNotEqual(parisCalendar.component(.day, from: parisModel.date), nyCalendar.component(.day, from: nyModel.date))
    }

    func testRefreshRequestsSharedNinetyMinuteBoundary() {
        let now = utcDate("2026-08-25T08:00:00Z")
        let timeline = WeatherTimelineBuilder().build(snapshot: SampleWeatherFactory.make(fetchedAt: now), from: now)
        XCTAssertEqual(timeline.requestedRefreshDate, utcDate("2026-08-25T09:05:00Z"))
    }

    func testRefreshIsNotRequestedMoreFrequentlyThanFifteenMinutes() {
        let now = utcDate("2026-08-25T09:00:00Z")
        let timeline = WeatherTimelineBuilder().build(snapshot: SampleWeatherFactory.make(fetchedAt: now.addingTimeInterval(-10_000)), from: now)
        XCTAssertGreaterThanOrEqual(timeline.requestedRefreshDate.timeIntervalSince(now), 15 * 60)
    }

    func testFreshnessBecomesStaleThenVeryStale() {
        let fetched = utcDate("2026-08-25T08:00:00Z")
        let snapshot = SampleWeatherFactory.make(fetchedAt: fetched)
        XCTAssertEqual(snapshot.freshness(at: fetched.addingTimeInterval(60 * 60)), .fresh)
        XCTAssertEqual(snapshot.freshness(at: fetched.addingTimeInterval(2 * 60 * 60)), .stale)
        XCTAssertEqual(snapshot.freshness(at: fetched.addingTimeInterval(7 * 60 * 60)), .veryStale)
    }
}
