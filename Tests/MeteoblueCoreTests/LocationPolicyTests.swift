import XCTest
@testable import MeteoblueCore

final class LocationPolicyTests: XCTestCase {
    let now = utcDate("2026-08-25T08:00:00Z")
    let policy = LocationPolicy()

    func sample(lat: Double = 49.402, lon: Double = 5.982, age: TimeInterval = 0, accuracy: Double = 50) -> LocationSample {
        LocationSample(coordinate: .init(latitude: lat, longitude: lon), timestamp: now.addingTimeInterval(-age), horizontalAccuracyMeters: accuracy)
    }

    func testFirstValidLocationIsAccepted() {
        XCTAssertEqual(policy.decide(candidate: sample(), previous: nil, now: now), .accept(sample(), distanceKilometers: nil))
    }

    func testUnavailableLocationRetainsPrevious() {
        let old = sample()
        XCTAssertEqual(policy.decide(candidate: nil, previous: old, now: now), .retain(old, .unavailable))
    }

    func testUnavailableWithNoHistoryIsUnavailable() {
        XCTAssertEqual(policy.decide(candidate: nil, previous: nil, now: now), .unavailable(.unavailable))
    }

    func testMovementBelowTwoKilometersRetainsPrevious() {
        let old = sample()
        let nearby = sample(lat: 49.410, lon: 5.982)
        XCTAssertEqual(policy.decide(candidate: nearby, previous: old, now: now), .retain(old, .insignificantMovement))
    }

    func testHyperlocalMovementAboveTwoKilometersIsAccepted() {
        let old = sample()
        let aumetzSide = sample(lat: 49.410, lon: 5.950)
        guard case .accept(let accepted, let distance) = policy.decide(candidate: aumetzSide, previous: old, now: now) else {
            return XCTFail("Expected hyperlocal move to be accepted")
        }
        XCTAssertEqual(accepted, aumetzSide)
        XCTAssertGreaterThan(distance ?? 0, 2)
    }

    func testCoarseGPSDoesNotTriggerZoneChangeInsideItsUncertainty() {
        let old = sample(accuracy: 3_000)
        let candidate = sample(lat: 49.410, lon: 5.950, accuracy: 100)
        XCTAssertEqual(policy.decide(candidate: candidate, previous: old, now: now), .retain(old, .insignificantMovement))
    }

    func testMovementAboveThresholdIsAccepted() {
        let old = sample()
        let paris = sample(lat: 48.8566, lon: 2.3522)
        guard case .accept(let accepted, let distance) = policy.decide(candidate: paris, previous: old, now: now) else {
            return XCTFail("Expected accepted move")
        }
        XCTAssertEqual(accepted, paris)
        XCTAssertGreaterThan(distance ?? 0, 2)
    }

    func testStalePositionRetainsPrevious() {
        let old = sample()
        let stale = sample(lat: 48.8566, lon: 2.3522, age: 7 * 60 * 60)
        XCTAssertEqual(policy.decide(candidate: stale, previous: old, now: now), .retain(old, .tooOld))
    }

    func testImprecisePositionRetainsPrevious() {
        let old = sample()
        let bad = sample(lat: 48.8566, lon: 2.3522, accuracy: 6_000)
        XCTAssertEqual(policy.decide(candidate: bad, previous: old, now: now), .retain(old, .tooImprecise))
    }

    func testReturnToPreviousZoneIsAcceptedFromFarZone() {
        let paris = sample(lat: 48.8566, lon: 2.3522)
        let tressange = sample()
        guard case .accept(let accepted, _) = policy.decide(candidate: tressange, previous: paris, now: now) else {
            return XCTFail("Expected return move")
        }
        XCTAssertEqual(accepted.coordinate, tressange.coordinate)
    }
}
