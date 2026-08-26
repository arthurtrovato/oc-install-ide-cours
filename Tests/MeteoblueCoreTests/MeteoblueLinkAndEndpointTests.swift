import XCTest
@testable import MeteoblueCore

final class MeteoblueLinkAndEndpointTests: XCTestCase {
    let location = WeatherLocation(
        coordinate: .init(latitude: 49.402, longitude: 5.982),
        locality: "Tressange",
        countryCode: "FR",
        timeZoneIdentifier: "Europe/Paris",
        elevationMeters: 320
    )

    func testFrenchWebURLUsesUniversalLinkPathAndExactCoordinates() throws {
        let url = try MeteoblueForecastLinkBuilder.webURL(for: location)
        XCTAssertEqual(url.host, "www.meteoblue.com")
        XCTAssertTrue(url.absoluteString.contains("/fr/meteo/semaine/"))
        XCTAssertTrue(url.absoluteString.contains("49.402N5.982E320_Europe%2FParis"))
    }

    func testRelayRoundTripPreservesDisplayedPlaceURL() throws {
        let target = try MeteoblueForecastLinkBuilder.webURL(for: location)
        let relay = try MeteoblueForecastLinkBuilder.relayURL(for: target)
        XCTAssertEqual(MeteoblueForecastLinkBuilder.validatedTarget(from: relay), target)
    }

    func testRelayRejectsNonMeteoblueTarget() {
        let evil = URL(string: "meteoblueweather://open?target=https%3A%2F%2Fevil.example%2F")!
        XCTAssertNil(MeteoblueForecastLinkBuilder.validatedTarget(from: evil))
    }

    func testOfficialAppShortcutURLIsStrictlyValidated() {
        let shortcut = MeteoblueForecastLinkBuilder.officialAppShortcutURL
        XCTAssertEqual(shortcut.scheme, "shortcuts")
        XCTAssertTrue(MeteoblueForecastLinkBuilder.isOfficialAppShortcutURL(shortcut))
        XCTAssertFalse(MeteoblueForecastLinkBuilder.isOfficialAppShortcutURL(URL(string: "shortcuts://run-shortcut?name=Other")!))
    }

    func testEndpointCombinesBasicHourlyAndDailyPackages() throws {
        let url = try DirectMeteoblueEndpoint().requestURL(for: location, apiKey: "TEST_KEY")
        XCTAssertEqual(url.path, "/packages/basic-1h_basic-day")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first(where: { $0.name == "forecast_days" })?.value, "7")
        XCTAssertEqual(items.first(where: { $0.name == "tz" })?.value, "Europe/Paris")
        XCTAssertEqual(items.first(where: { $0.name == "apikey" })?.value, "TEST_KEY")
    }

    func testMissingAPIKeyIsRejectedBeforeNetwork() {
        XCTAssertThrowsError(try DirectMeteoblueEndpoint().requestURL(for: location, apiKey: "  ")) {
            XCTAssertEqual($0 as? WeatherServiceError, .missingAPIKey)
        }
    }

    func testProxyEndpointDoesNotUseAPIKey() throws {
        let endpoint = ProxyMeteoblueEndpoint(baseURL: URL(string: "https://example.test/weather")!)
        let url = try endpoint.requestURL(for: location, apiKey: "TOP_SECRET")
        XCTAssertFalse(url.absoluteString.contains("TOP_SECRET"))
        XCTAssertTrue(url.absoluteString.contains("lat="))
    }
}
