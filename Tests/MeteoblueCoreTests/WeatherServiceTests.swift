import XCTest
@testable import MeteoblueCore

final class WeatherServiceTests: XCTestCase {
    let location = WeatherLocation(coordinate: .init(latitude: 49.402, longitude: 5.982), locality: "Tressange", countryCode: "FR", timeZoneIdentifier: "Europe/Paris", elevationMeters: 320)
    let now = utcDate("2026-08-25T08:00:00Z")

    func testServiceDecodesSuccessfulHTTPResponse() async throws {
        let service = MeteoblueWeatherService(
            apiKeyProvider: { "TEST_KEY" },
            httpClient: StubHTTPClient(result: .success(.init(data: try fixtureData("meteoblue-realistic"), statusCode: 200)))
        )
        let snapshot = try await service.fetchWeather(for: location, at: now)
        XCTAssertEqual(snapshot.current.temperatureCelsius, 14.3, accuracy: 0.001)
    }

    func testServiceUsesResolvedMeteoblueElevationInForecastLink() async throws {
        let locationWithoutAltitude = WeatherLocation(
            coordinate: .init(latitude: 49.402, longitude: 5.982),
            locality: "Tressange",
            countryCode: "FR",
            timeZoneIdentifier: "Europe/Paris",
            elevationMeters: nil
        )
        let service = MeteoblueWeatherService(
            apiKeyProvider: { "TEST_KEY" },
            httpClient: StubHTTPClient(result: .success(.init(data: try fixtureData("meteoblue-realistic"), statusCode: 200)))
        )

        let snapshot = try await service.fetchWeather(for: locationWithoutAltitude, at: now)

        XCTAssertEqual(snapshot.location.elevationMeters, 320)
        XCTAssertTrue(snapshot.meteoblueURL.absoluteString.contains("49.402N5.982E320_Europe%2FParis"))
        XCTAssertFalse(snapshot.meteoblueURL.absoluteString.contains("49.402N5.982E0_Europe%2FParis"))
    }

    func testServiceRejectsHTTPError() async {
        let service = MeteoblueWeatherService(apiKeyProvider: { "TEST_KEY" }, httpClient: StubHTTPClient(result: .success(.init(data: Data(), statusCode: 503))))
        do {
            _ = try await service.fetchWeather(for: location, at: now)
            XCTFail("Expected HTTP error")
        } catch {
            XCTAssertEqual(error as? WeatherServiceError, .httpStatus(503))
        }
    }

    func testServiceRejectsEmptyBody() async {
        let service = MeteoblueWeatherService(apiKeyProvider: { "TEST_KEY" }, httpClient: StubHTTPClient(result: .success(.init(data: Data(), statusCode: 200))))
        do {
            _ = try await service.fetchWeather(for: location, at: now)
            XCTFail("Expected empty response error")
        } catch {
            XCTAssertEqual(error as? WeatherServiceError, .emptyResponse)
        }
    }

    func testServiceRejectsMissingAPIKey() async {
        let service = MeteoblueWeatherService(apiKeyProvider: { nil }, httpClient: StubHTTPClient(result: .failure(.transportFailure)))
        do {
            _ = try await service.fetchWeather(for: location, at: now)
            XCTFail("Expected missing key")
        } catch {
            XCTAssertEqual(error as? WeatherServiceError, .missingAPIKey)
        }
    }

    func testTransportErrorIsPropagated() async {
        let service = MeteoblueWeatherService(apiKeyProvider: { "TEST_KEY" }, httpClient: StubHTTPClient(result: .failure(.transportFailure)))
        do {
            _ = try await service.fetchWeather(for: location, at: now)
            XCTFail("Expected transport error")
        } catch {
            XCTAssertEqual(error as? WeatherServiceError, .transportFailure)
        }
    }
}
