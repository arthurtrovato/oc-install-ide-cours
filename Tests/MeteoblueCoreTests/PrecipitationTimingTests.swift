import XCTest
@testable import MeteoblueCore

final class PrecipitationTimingTests: XCTestCase {
    func testShortContinuousRainUsesExactRange() {
        let model = makeModel(wetHours: [8, 9], dailyTotal: 1.2)
        let summary = model.todayPrecipitationSummary
        XCTAssertEqual(summary.totalMillimeters ?? -1, 1.2, accuracy: 0.001)
        XCTAssertEqual(summary.timingAbbreviation, "8–10h")
        XCTAssertEqual(summary.timingDescription, "de 8 h à 10 h")
    }

    func testTwoShortRainWindowsStayPrecise() {
        let model = makeModel(wetHours: [8, 17], dailyTotal: 1.8)
        let summary = model.todayPrecipitationSummary
        XCTAssertEqual(summary.timingAbbreviation, "8–9/17–18h")
        XCTAssertEqual(summary.timingDescription, "de 8 h à 9 h et de 17 h à 18 h")
    }

    func testEarlyMorningUsesCompactSemanticAbbreviation() {
        let model = makeModel(wetHours: [5, 6, 7], dailyTotal: 2.4)
        let summary = model.todayPrecipitationSummary
        XCTAssertEqual(summary.timingAbbreviation, "d.mat.")
        XCTAssertEqual(summary.timingDescription, "début de matinée")
    }

    func testLongMorningCollapsesToMorning() {
        let model = makeModel(wetHours: Array(5...12), dailyTotal: 4.8)
        let summary = model.todayPrecipitationSummary
        XCTAssertEqual(summary.timingAbbreviation, "mat.")
        XCTAssertEqual(summary.timingDescription, "matinée")
    }

    func testScatteredRainAcrossDayCollapsesToWholeDay() {
        let model = makeModel(wetHours: [1, 7, 14, 20], dailyTotal: 3.6)
        let summary = model.todayPrecipitationSummary
        XCTAssertEqual(summary.timingAbbreviation, "tte j.")
        XCTAssertEqual(summary.timingDescription, "toute la journée")
    }

    func testHourlyTotalIsFallbackWhenDailyTotalMissing() {
        let model = makeModel(wetHours: [14, 15], dailyTotal: nil)
        let summary = model.todayPrecipitationSummary
        XCTAssertEqual(summary.totalMillimeters ?? -1, 1.2, accuracy: 0.001)
        XCTAssertEqual(summary.timingAbbreviation, "14–16h")
    }

    func testNoRainHasNoTimingLabel() {
        let model = makeModel(wetHours: [], dailyTotal: 0)
        let summary = model.todayPrecipitationSummary
        XCTAssertEqual(summary.totalMillimeters ?? -1, 0, accuracy: 0.001)
        XCTAssertNil(summary.timingAbbreviation)
        XCTAssertNil(summary.timingDescription)
    }

    private func makeModel(wetHours: [Int], dailyTotal: Double?) -> WeatherDisplayModel {
        let zone = "Europe/Paris"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        let dayStart = localDate("2026-08-27 00:00", zone: zone)
        let now = localDate("2026-08-27 07:30", zone: zone)

        let hourly = (0..<24).map { hour -> HourlyForecast in
            let date = calendar.date(byAdding: .hour, value: hour, to: dayStart)!
            let wet = wetHours.contains(hour)
            return HourlyForecast(
                date: date,
                temperatureCelsius: 15 + Double(hour) / 10,
                condition: wet ? .rain : .partlyCloudy,
                isDaylight: (7..<20).contains(hour),
                precipitationProbabilityPercent: wet ? 80 : 5,
                precipitationMillimeters: wet ? 0.6 : 0,
                sourcePictocode: wet ? 23 : 7
            )
        }

        let location = WeatherLocation(
            coordinate: GeoCoordinate(latitude: 49.4, longitude: 5.98),
            locality: "Tressange",
            countryCode: "FR",
            timeZoneIdentifier: zone,
            elevationMeters: 320
        )
        let daily = [
            DailyForecast(
                date: dayStart,
                minimumCelsius: 10,
                maximumCelsius: 22,
                condition: wetHours.isEmpty ? .partlyCloudy : .rain,
                precipitationProbabilityPercent: wetHours.isEmpty ? 5 : 80,
                precipitationMillimeters: dailyTotal,
                sourcePictocode: wetHours.isEmpty ? 3 : 6
            )
        ]
        let snapshot = WeatherSnapshot(
            fetchedAt: now,
            location: location,
            current: CurrentConditions(
                date: now,
                temperatureCelsius: 16,
                condition: .partlyCloudy,
                isDaylight: true
            ),
            hourly: hourly,
            daily: daily,
            meteoblueURL: try! MeteoblueForecastLinkBuilder.webURL(for: location)
        )
        return WeatherTimelineBuilder(hourlyCount: 6, dailyCount: 5).displayModel(snapshot: snapshot, at: now)
    }
}
