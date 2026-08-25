import XCTest
@testable import MeteoblueCore

final class MeteoblueLiveIntegrationTests: XCTestCase {
    func testLiveMeteoblueResponseWhenExplicitlyEnabled() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["RUN_METEOBLUE_LIVE_TEST"] == "1" else {
            throw XCTSkip("Live meteoblue integration test is opt-in.")
        }
        guard let key = env["METEOBLUE_API_KEY"], !key.isEmpty else {
            XCTFail("RUN_METEOBLUE_LIVE_TEST is enabled but METEOBLUE_API_KEY is unavailable.")
            return
        }
        let location = WeatherLocation(
            coordinate: .init(latitude: 49.402, longitude: 5.982),
            locality: "Tressange",
            countryCode: "FR",
            timeZoneIdentifier: "Europe/Paris",
            elevationMeters: 320
        )
        let service = MeteoblueWeatherService(apiKeyProvider: { key })
        let snapshot = try await service.fetchWeather(for: location, at: Date())
        XCTAssertFalse(snapshot.hourly.isEmpty)
        XCTAssertGreaterThanOrEqual(snapshot.daily.count, 5)
        XCTAssertTrue(snapshot.current.temperatureCelsius.isFinite)
        XCTAssertEqual(snapshot.meteoblueURL.host, "www.meteoblue.com")
    }
}
