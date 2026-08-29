import XCTest
@testable import MeteoblueCore

final class DiagnosticsTests: XCTestCase {
    func testDiagnosticsNeverExposeConfiguredSecret() {
        var diagnostics = DiagnosticsSnapshot(appVersion: "1.0", deepLinkState: "https://www.meteoblue.com/path?apikey=ALSO_SECRET")
        diagnostics.lastError = "request failed api_key=ALSO_SECRET"
        let text = diagnostics.sanitizedText(additionalSecrets: ["SUPER_SECRET", "ALSO_SECRET"])
        XCTAssertFalse(text.contains("SUPER_SECRET"))
        XCTAssertFalse(text.contains("ALSO_SECRET"))
        XCTAssertTrue(text.contains("[REDACTED]"))
    }

    func testDiagnosticsContainsOperationalAndForecastRunFields() {
        var diagnostics = DiagnosticsSnapshot(appVersion: "1.2.3", deepLinkState: "ready")
        diagnostics.displayedLocality = "Tressange"
        diagnostics.cacheSource = .freshCache
        diagnostics.lastCoordinate = .init(latitude: 49.402, longitude: 5.982)
        diagnostics.forecastFetchedAt = utcDate("2026-08-25T08:00:00Z")
        diagnostics.forecastModelRunUTC = "2026-08-25 06:00"
        diagnostics.forecastModelRunUpdateUTC = "2026-08-25 07:12"
        let text = diagnostics.sanitizedText()
        XCTAssertTrue(text.contains("Tressange"))
        XCTAssertTrue(text.contains("freshCache"))
        XCTAssertTrue(text.contains("coordinate="))
        XCTAssertTrue(text.contains("forecast_fetched_at="))
        XCTAssertTrue(text.contains("modelrun_utc=2026-08-25 06:00"))
        XCTAssertTrue(text.contains("modelrun_updatetime_utc=2026-08-25 07:12"))
    }
}
