import Foundation
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
        let endpoint = DirectMeteoblueEndpoint()
        let requestURL = try endpoint.requestURL(for: location, apiKey: key)
        let response = try await URLSessionHTTPClient().get(requestURL)

        guard (200..<300).contains(response.statusCode) else {
            let body = String(data: response.data, encoding: .utf8) ?? "<non-UTF8 response>"
            let sanitized = body.replacingOccurrences(of: key, with: "[REDACTED]")
            XCTFail("meteoblue live request returned HTTP \(response.statusCode): \(sanitized.prefix(600))")
            return
        }

        let payload = try MeteobluePayloadDecoder.decode(response.data)
        let snapshot = try MeteoblueTransformer.makeSnapshot(
            payload: payload,
            requestedLocation: location,
            fetchedAt: Date(),
            meteoblueURL: try MeteoblueForecastLinkBuilder.webURL(for: location)
        )
        XCTAssertFalse(snapshot.hourly.isEmpty)
        XCTAssertGreaterThanOrEqual(snapshot.daily.count, 5)
        XCTAssertTrue(snapshot.current.temperatureCelsius.isFinite)
        XCTAssertNotEqual(snapshot.hourly.first?.condition, .unknown)
        XCTAssertTrue(snapshot.hourly.contains { $0.precipitationProbabilityPercent != nil })
        XCTAssertTrue(snapshot.daily.contains { $0.precipitationProbabilityPercent != nil })
        XCTAssertEqual(snapshot.meteoblueURL.host, "www.meteoblue.com")
    }
}
