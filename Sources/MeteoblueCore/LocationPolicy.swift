import Foundation

public struct LocationSample: Codable, Equatable, Sendable {
    public let coordinate: GeoCoordinate
    public let timestamp: Date
    public let horizontalAccuracyMeters: Double

    public init(coordinate: GeoCoordinate, timestamp: Date, horizontalAccuracyMeters: Double) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
    }
}

public enum LocationRejectionReason: String, Codable, Equatable, Sendable {
    case unavailable
    case invalidCoordinate
    case tooOld
    case tooImprecise
    case insignificantMovement
}

public enum LocationDecision: Equatable, Sendable {
    case accept(LocationSample, distanceKilometers: Double?)
    case retain(LocationSample, LocationRejectionReason)
    case unavailable(LocationRejectionReason)
}

public struct LocationPolicy: Sendable {
    public static let defaultMovementThresholdKilometers = 2.0

    public let movementThresholdKilometers: Double
    public let maximumAge: TimeInterval
    public let maximumHorizontalAccuracyMeters: Double

    public init(
        movementThresholdKilometers: Double = LocationPolicy.defaultMovementThresholdKilometers,
        maximumAge: TimeInterval = 6 * 60 * 60,
        maximumHorizontalAccuracyMeters: Double = 5_000
    ) {
        self.movementThresholdKilometers = max(0.1, movementThresholdKilometers)
        self.maximumAge = maximumAge
        self.maximumHorizontalAccuracyMeters = maximumHorizontalAccuracyMeters
    }

    public func decide(candidate: LocationSample?, previous: LocationSample?, now: Date) -> LocationDecision {
        guard let candidate else {
            return previous.map { .retain($0, .unavailable) } ?? .unavailable(.unavailable)
        }
        guard candidate.coordinate.isValid else {
            return previous.map { .retain($0, .invalidCoordinate) } ?? .unavailable(.invalidCoordinate)
        }
        guard candidate.timestamp <= now.addingTimeInterval(5 * 60),
              max(0, now.timeIntervalSince(candidate.timestamp)) <= maximumAge else {
            return previous.map { .retain($0, .tooOld) } ?? .unavailable(.tooOld)
        }
        guard candidate.horizontalAccuracyMeters >= 0,
              candidate.horizontalAccuracyMeters.isFinite,
              candidate.horizontalAccuracyMeters <= maximumHorizontalAccuracyMeters else {
            return previous.map { .retain($0, .tooImprecise) } ?? .unavailable(.tooImprecise)
        }
        guard let previous else { return .accept(candidate, distanceKilometers: nil) }

        let distance = previous.coordinate.distanceKilometers(to: candidate.coordinate)
        // Do not let coarse GPS noise trigger a hyperlocal weather-zone change. Precise
        // fixes can move after 2 km, while a coarse fix must exceed its own uncertainty.
        let uncertaintyKilometers = max(previous.horizontalAccuracyMeters, candidate.horizontalAccuracyMeters) / 1_000
        let effectiveThreshold = max(movementThresholdKilometers, uncertaintyKilometers)
        if distance < effectiveThreshold {
            return .retain(previous, .insignificantMovement)
        }
        return .accept(candidate, distanceKilometers: distance)
    }
}
