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

    func testDiagnosticsContainsOperationalFields() {
        var diagnostics = DiagnosticsSnapshot(appVersion: "1.2.3", deepLinkState: "ready")
        diagnostics.displayedLocality = "Tressange"
        diagnostics.cacheSource = .freshCache
        diagnostics.lastCoordinate = .init(latitude: 49.402, longitude: 5.982)
        let text = diagnostics.sanitizedText()
        XCTAssertTrue(text.contains("Tressange"))
        XCTAssertTrue(text.contains("freshCache"))
        XCTAssertTrue(text.contains("coordinate="))
    }
}
