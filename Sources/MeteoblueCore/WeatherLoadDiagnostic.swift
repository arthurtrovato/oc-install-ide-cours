import Foundation

public struct WeatherLoadDiagnostic: Equatable, Sendable {
    public let surface: String
    public let source: WeatherLoadSource
    public let observedAt: Date
    public let fetchedAt: Date
    public let snapshotAgeSeconds: TimeInterval
    public let forecastRunIdentifier: String?
    public let locality: String
    public let coordinate: GeoCoordinate
    public let precipitationMillimeters: Double?
    public let precipitationTiming: String?
    public let firstVisibleHour: Date?
    public let nextRequestedRefresh: Date

    public init(
        surface: String,
        result: WeatherLoadResult,
        timeline: WeatherTimeline,
        observedAt: Date
    ) {
        let first = timeline.entries.first
        self.surface = surface
        self.source = result.source
        self.observedAt = observedAt
        self.fetchedAt = result.snapshot.fetchedAt
        self.snapshotAgeSeconds = max(0, observedAt.timeIntervalSince(result.snapshot.fetchedAt))
        self.forecastRunIdentifier = result.snapshot.forecastRunIdentifier
        self.locality = result.snapshot.location.locality
        self.coordinate = result.snapshot.location.coordinate
        self.precipitationMillimeters = first?.todayPrecipitationSummary.totalMillimeters
        self.precipitationTiming = first?.todayPrecipitationSummary.timingAbbreviation
        self.firstVisibleHour = first?.nextHours.first?.date
        self.nextRequestedRefresh = timeline.requestedRefreshDate
    }

    public var logLine: String {
        let iso = ISO8601DateFormatter()
        let precipitation = precipitationMillimeters.map { String(format: "%.2f", $0) } ?? "none"
        let firstHour = firstVisibleHour.map { iso.string(from: $0) } ?? "none"
        return [
            "METEOBLUE_SNAPSHOT",
            "surface=\(surface)",
            "source=\(source.rawValue)",
            "observed_at=\(iso.string(from: observedAt))",
            "fetched_at=\(iso.string(from: fetchedAt))",
            "age_s=\(Int(snapshotAgeSeconds.rounded()))",
            "run=\(forecastRunIdentifier ?? "none")",
            "locality=\(locality)",
            String(format: "coordinate=%.5f,%.5f", coordinate.latitude, coordinate.longitude),
            "rain_mm=\(precipitation)",
            "rain_timing=\(precipitationTiming ?? "none")",
            "first_hour=\(firstHour)",
            "next_refresh=\(iso.string(from: nextRequestedRefresh))"
        ].joined(separator: " ")
    }
}
