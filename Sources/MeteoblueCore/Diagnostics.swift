import Foundation

public struct DiagnosticsSnapshot: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var locationAuthorization: String
    public var widgetLocationAuthorized: Bool
    public var lastCoordinate: GeoCoordinate?
    public var locationAccuracyMeters: Double?
    public var locationAgeSeconds: TimeInterval?
    public var displayedLocality: String?
    public var lastMeteoblueCall: Date?
    public var cacheAgeSeconds: TimeInterval?
    public var nextRequestedRefresh: Date?
    public var lastError: String?
    public var appVersion: String
    public var deepLinkState: String
    public var cacheSource: WeatherLoadSource?

    public init(
        generatedAt: Date = Date(),
        locationAuthorization: String = "unknown",
        widgetLocationAuthorized: Bool = false,
        lastCoordinate: GeoCoordinate? = nil,
        locationAccuracyMeters: Double? = nil,
        locationAgeSeconds: TimeInterval? = nil,
        displayedLocality: String? = nil,
        lastMeteoblueCall: Date? = nil,
        cacheAgeSeconds: TimeInterval? = nil,
        nextRequestedRefresh: Date? = nil,
        lastError: String? = nil,
        appVersion: String = "unknown",
        deepLinkState: String = "unknown",
        cacheSource: WeatherLoadSource? = nil
    ) {
        self.generatedAt = generatedAt
        self.locationAuthorization = locationAuthorization
        self.widgetLocationAuthorized = widgetLocationAuthorized
        self.lastCoordinate = lastCoordinate
        self.locationAccuracyMeters = locationAccuracyMeters
        self.locationAgeSeconds = locationAgeSeconds
        self.displayedLocality = displayedLocality
        self.lastMeteoblueCall = lastMeteoblueCall
        self.cacheAgeSeconds = cacheAgeSeconds
        self.nextRequestedRefresh = nextRequestedRefresh
        self.lastError = lastError
        self.appVersion = appVersion
        self.deepLinkState = deepLinkState
        self.cacheSource = cacheSource
    }

    public func sanitizedText(additionalSecrets: [String] = []) -> String {
        let iso = ISO8601DateFormatter()
        var lines = [
            "Meteoblue Weather diagnostics",
            "generated_at=\(iso.string(from: generatedAt))",
            "app_version=\(appVersion)",
            "location_authorization=\(locationAuthorization)",
            "widget_location_authorized=\(widgetLocationAuthorized)",
            "locality=\(displayedLocality ?? "none")",
            "cache_source=\(cacheSource?.rawValue ?? "none")",
            "deep_link=\(deepLinkState)"
        ]
        if let coordinate = lastCoordinate {
            lines.append(String(format: "coordinate=%.5f,%.5f", coordinate.latitude, coordinate.longitude))
        }
        if let accuracy = locationAccuracyMeters { lines.append(String(format: "accuracy_m=%.0f", accuracy)) }
        if let age = locationAgeSeconds { lines.append(String(format: "location_age_s=%.0f", age)) }
        if let call = lastMeteoblueCall { lines.append("last_meteoblue_call=\(iso.string(from: call))") }
        if let age = cacheAgeSeconds { lines.append(String(format: "cache_age_s=%.0f", age)) }
        if let next = nextRequestedRefresh { lines.append("next_requested_refresh=\(iso.string(from: next))") }
        if let error = lastError { lines.append("last_error=\(error)") }
        var text = lines.joined(separator: "\n")
        for secret in additionalSecrets where !secret.isEmpty {
            text = text.replacingOccurrences(of: secret, with: "[REDACTED]")
        }
        text = redactAPIKeyQuery(in: text)
        return text
    }

    private func redactAPIKeyQuery(in input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "(?i)(apikey|api_key|key)=([^&\\s]+)") else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: "$1=[REDACTED]")
    }
}
