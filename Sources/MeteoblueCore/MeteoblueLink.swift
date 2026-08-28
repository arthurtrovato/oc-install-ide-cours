import Foundation

public enum MeteoblueForecastLinkBuilder {
    public static let relayScheme = "meteoblueweather"
    public static let officialAppShortcutName = "Ouvrir meteoblue"

    public static var officialAppShortcutURL: URL {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: officialAppShortcutName)]
        return components.url!
    }

    public static func webURL(for location: WeatherLocation, language: String = "fr") throws -> URL {
        guard location.coordinate.isValid else { throw WeatherServiceError.invalidRequest }
        let latHemisphere = location.coordinate.latitude >= 0 ? "N" : "S"
        let lonHemisphere = location.coordinate.longitude >= 0 ? "E" : "W"
        let lat = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), abs(location.coordinate.latitude))
        let lon = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), abs(location.coordinate.longitude))
        let elevation = Int((location.elevationMeters ?? 0).rounded())
        let zone = encodePathComponent(location.timeZoneIdentifier)
        let segments = pathSegments(for: language)
        let slug = "\(lat)\(latHemisphere)\(lon)\(lonHemisphere)\(elevation)_\(zone)"
        let raw = "https://www.meteoblue.com/\(segments.language)/\(segments.forecast)/\(slug)"
        guard let url = URL(string: raw) else { throw WeatherServiceError.invalidRequest }
        return url
    }

    public static func canonicalWebURL(slug: String, language: String = "fr") -> URL? {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains("?"),
              !trimmed.contains("#") else { return nil }
        let segments = pathSegments(for: language)
        guard let url = URL(string: "https://www.meteoblue.com/\(segments.language)/\(segments.forecast)/\(trimmed)"),
              isAllowedMeteoblueURL(url) else { return nil }
        return url
    }

    public static func relayURL(for meteoblueURL: URL) throws -> URL {
        guard isAllowedMeteoblueURL(meteoblueURL) else { throw WeatherServiceError.invalidRequest }
        var components = URLComponents()
        components.scheme = relayScheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "target", value: meteoblueURL.absoluteString)]
        guard let url = components.url else { throw WeatherServiceError.invalidRequest }
        return url
    }

    public static func validatedTarget(from relayURL: URL) -> URL? {
        guard relayURL.scheme?.lowercased() == relayScheme,
              relayURL.host?.lowercased() == "open",
              let components = URLComponents(url: relayURL, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name == "target" })?.value,
              let target = URL(string: raw),
              isAllowedMeteoblueURL(target) else { return nil }
        return target
    }

    public static func isOfficialAppShortcutURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "shortcuts",
              url.host?.lowercased() == "run-shortcut",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.queryItems?.first(where: { $0.name == "name" })?.value == officialAppShortcutName else {
            return false
        }
        return true
    }

    public static func isAllowedMeteoblueURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              host == "www.meteoblue.com" || host == "meteoblue.com" else { return false }
        let path = url.path.lowercased()
        return path.contains("/weather/week/") ||
            path.contains("/meteo/semaine/") ||
            path.contains("/wetter/woche/") ||
            path.contains("/tiempo/semana/") ||
            path.contains("/tempo/settimana/")
    }

    static func pathSegments(for language: String) -> (language: String, forecast: String) {
        switch language.lowercased() {
        case "de": return ("de", "wetter/woche")
        case "es": return ("es", "tiempo/semana")
        case "it": return ("it", "tempo/settimana")
        case "en": return ("en", "weather/week")
        default: return ("fr", "meteo/semaine")
        }
    }

    private static func encodePathComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#%")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value.replacingOccurrences(of: "/", with: "%2F")
    }
}

public protocol MeteoblueForecastURLResolving: Sendable {
    func canonicalForecastURL(for location: WeatherLocation, apiKey: String, language: String) async -> URL?
}

public struct MeteoblueLocationSearchResolver: MeteoblueForecastURLResolving, Sendable {
    private let httpClient: any HTTPClient
    private let maximumDistanceKilometers: Double

    public init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        maximumDistanceKilometers: Double = 20
    ) {
        self.httpClient = httpClient
        self.maximumDistanceKilometers = maximumDistanceKilometers
    }

    public func canonicalForecastURL(
        for location: WeatherLocation,
        apiKey: String,
        language: String = "fr"
    ) async -> URL? {
        guard location.coordinate.isValid else { return nil }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }

        let segments = MeteoblueForecastLinkBuilder.pathSegments(for: language)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.meteoblue.com"
        components.path = "/\(segments.language)/server/search/query3"
        let lat = String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), location.coordinate.latitude)
        let lon = String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), location.coordinate.longitude)
        components.queryItems = [
            URLQueryItem(name: "query", value: "\(lat) \(lon)"),
            URLQueryItem(name: "itemsPerPage", value: "10"),
            URLQueryItem(name: "apikey", value: key)
        ]
        guard let requestURL = components.url,
              let result = try? await httpClient.get(requestURL),
              (200..<300).contains(result.statusCode),
              !result.data.isEmpty,
              let response = try? JSONDecoder().decode(LocationSearchResponse.self, from: result.data),
              !response.results.isEmpty else { return nil }

        let candidate = response.results.min { lhs, rhs in
            (lhs.distance ?? .greatestFiniteMagnitude) < (rhs.distance ?? .greatestFiniteMagnitude)
        } ?? response.results[0]

        if let distance = candidate.distance, distance > maximumDistanceKilometers {
            return nil
        }
        return MeteoblueForecastLinkBuilder.canonicalWebURL(slug: candidate.url, language: language)
    }

    private struct LocationSearchResponse: Decodable {
        let results: [LocationSearchResult]
    }

    private struct LocationSearchResult: Decodable {
        let url: String
        let distance: Double?
    }
}
