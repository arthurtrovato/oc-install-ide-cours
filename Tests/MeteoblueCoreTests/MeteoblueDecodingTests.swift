import XCTest
@testable import MeteoblueCore

final class MeteoblueDecodingTests: XCTestCase {
    private let location = WeatherLocation(
        coordinate: .init(latitude: 49.402, longitude: 5.982),
        locality: "Tressange",
        countryCode: "FR",
        timeZoneIdentifier: "Europe/Paris",
        elevationMeters: 320
    )
    private let fetchedAt = utcDate("2026-08-25T08:00:00Z")

    func testDecodesRealisticFixture() throws {
        let payload = try MeteobluePayloadDecoder.decode(fixtureData("meteoblue-realistic"))
        XCTAssertEqual(payload.metadata.latitude, 49.402)
        XCTAssertEqual(payload.metadata.timeZoneIdentifier, "Europe/Paris")
        XCTAssertEqual(payload.hourly?.time.count, 12)
        XCTAssertEqual(payload.daily?.time.count, 7)
    }

    func testCurrentDataIsDecodedAndTransformed() throws {
        let snapshot = try makeSnapshot("meteoblue-realistic")
        XCTAssertEqual(snapshot.current.temperatureCelsius, 14.3, accuracy: 0.001)
        XCTAssertEqual(snapshot.current.condition, .rain)
        XCTAssertEqual(snapshot.current.precipitationProbabilityPercent, 77)
        XCTAssertTrue(snapshot.current.isDaylight)
    }

    func testHourlyDataIncludesTemperaturePictocodeAndPrecipitation() throws {
        let snapshot = try makeSnapshot("meteoblue-realistic")
        XCTAssertEqual(snapshot.hourly.count, 12)
        XCTAssertEqual(snapshot.hourly[0].temperatureCelsius, 14.3, accuracy: 0.001)
        XCTAssertEqual(snapshot.hourly[0].condition, .rain)
        XCTAssertEqual(snapshot.hourly[2].condition, .showers)
        XCTAssertEqual(snapshot.hourly[0].precipitationMillimeters, 1.1)
    }

    func testDailyDataIncludesMinMaxAndProbability() throws {
        let snapshot = try makeSnapshot("meteoblue-realistic")
        XCTAssertEqual(snapshot.daily.count, 7)
        XCTAssertEqual(snapshot.daily[0].minimumCelsius, 12)
        XCTAssertEqual(snapshot.daily[0].maximumCelsius, 18)
        XCTAssertEqual(snapshot.daily[0].condition, .rain)
        XCTAssertEqual(snapshot.daily[0].precipitationProbabilityPercent, 82)
    }

    func testPartialResponseSkipsUnusableRowsAndClampsProbability() throws {
        let snapshot = try makeSnapshot("meteoblue-partial")
        XCTAssertEqual(snapshot.hourly.count, 2)
        XCTAssertEqual(snapshot.daily.count, 1)
        XCTAssertEqual(snapshot.hourly.last?.precipitationProbabilityPercent, 100)
        XCTAssertEqual(snapshot.current.temperatureCelsius, 14.5, accuracy: 0.001)
    }

    func testMalformedJSONThrows() {
        XCTAssertThrowsError(try MeteobluePayloadDecoder.decode(Data("not-json".utf8))) {
            XCTAssertEqual($0 as? MeteobluePayloadError, .malformedJSON)
        }
    }

    func testResponseWithoutForecastThrows() {
        XCTAssertThrowsError(try MeteobluePayloadDecoder.decode(Data("{\"metadata\":{}}".utf8))) {
            XCTAssertEqual($0 as? MeteobluePayloadError, .noForecastData)
        }
    }

    func testMissingHourlyRowsFailsTransformation() throws {
        let data = Data("{\"data_day\":{\"time\":[\"2026-08-25\"],\"temperature_min\":[10],\"temperature_max\":[20],\"pictocode\":[1]}}".utf8)
        let payload = try MeteobluePayloadDecoder.decode(data)
        XCTAssertThrowsError(try MeteoblueTransformer.makeSnapshot(payload: payload, requestedLocation: location, fetchedAt: fetchedAt, meteoblueURL: try MeteoblueForecastLinkBuilder.webURL(for: location))) {
            XCTAssertEqual($0 as? MeteobluePayloadError, .noUsableHourlyData)
        }
    }

    func testTimezoneParsingUsesLocationTimezone() throws {
        let snapshot = try makeSnapshot("meteoblue-realistic")
        XCTAssertEqual(snapshot.hourly[0].date, fetchedAt)
    }

    func testHourlyPictocodeAliasUsesHourlyPictogramSet() throws {
        let data = Data("{\"data_1h\":{\"time\":[\"2026-08-25 10:00\"],\"temperature\":[14],\"pictocode\":[23],\"isdaylight\":[true]},\"data_day\":{\"time\":[\"2026-08-25\"],\"temperature_min\":[10],\"temperature_max\":[18],\"pictocode\":[6]}}".utf8)
        let payload = try MeteobluePayloadDecoder.decode(data)
        let snapshot = try MeteoblueTransformer.makeSnapshot(
            payload: payload,
            requestedLocation: location,
            fetchedAt: fetchedAt,
            meteoblueURL: try MeteoblueForecastLinkBuilder.webURL(for: location)
        )
        XCTAssertEqual(snapshot.hourly.first?.condition, .rain)
        XCTAssertEqual(snapshot.daily.first?.condition, .rain)
    }

    private func makeSnapshot(_ fixture: String) throws -> WeatherSnapshot {
        let payload = try MeteobluePayloadDecoder.decode(fixtureData(fixture))
        return try MeteoblueTransformer.makeSnapshot(
            payload: payload,
            requestedLocation: location,
            fetchedAt: fetchedAt,
            meteoblueURL: try MeteoblueForecastLinkBuilder.webURL(for: location)
        )
    }
}
