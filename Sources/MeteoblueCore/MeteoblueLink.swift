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
        let languageSegment: String
        let forecastSegment: String
        switch language.lowercased() {
        case "de": languageSegment = "de"; forecastSegment = "wetter/woche"
        case "es": languageSegment = "es"; forecastSegment = "tiempo/semana"
        case "it": languageSegment = "it"; forecastSegment = "tempo/settimana"
        case "en": languageSegment = "en"; forecastSegment = "weather/week"
        default: languageSegment = "fr"; forecastSegment = "meteo/semaine"
        }
        let slug = "\(lat)\(latHemisphere)\(lon)\(lonHemisphere)\(elevation)_\(zone)"
        let raw = "https://www.meteoblue.com/\(languageSegment)/\(forecastSegment)/\(slug)"
        guard let url = URL(string: raw) else { throw WeatherServiceError.invalidRequest }
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

    private static func encodePathComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#%")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value.replacingOccurrences(of: "/", with: "%2F")
    }
}
