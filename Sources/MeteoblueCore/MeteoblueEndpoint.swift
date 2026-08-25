import Foundation

public protocol MeteoblueEndpointBuilding: Sendable {
    func requestURL(for location: WeatherLocation, apiKey: String) throws -> URL
}

public struct DirectMeteoblueEndpoint: MeteoblueEndpointBuilding, Sendable {
    public let host: String
    public let packages: [String]
    public let forecastDays: Int

    public init(
        host: String = "my.meteoblue.com",
        packages: [String] = ["basic-1h", "basic-day", "current"],
        forecastDays: Int = 7
    ) {
        self.host = host
        self.packages = packages
        self.forecastDays = forecastDays
    }

    public func requestURL(for location: WeatherLocation, apiKey: String) throws -> URL {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw WeatherServiceError.missingAPIKey }
        guard location.coordinate.isValid, !packages.isEmpty else { throw WeatherServiceError.invalidRequest }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/packages/" + packages.joined(separator: "_")
        var items: [URLQueryItem] = [
            .init(name: "lat", value: String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), location.coordinate.latitude)),
            .init(name: "lon", value: String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), location.coordinate.longitude)),
            .init(name: "apikey", value: key),
            .init(name: "format", value: "json"),
            .init(name: "temperature", value: "C"),
            .init(name: "precipitationamount", value: "mm"),
            .init(name: "forecast_days", value: String(max(5, min(7, forecastDays)))),
            .init(name: "tz", value: location.timeZoneIdentifier)
        ]
        if let elevation = location.elevationMeters, elevation.isFinite, elevation > -500, elevation < 9_000 {
            items.append(.init(name: "asl", value: String(Int(elevation.rounded()))))
        }
        components.queryItems = items
        guard let url = components.url else { throw WeatherServiceError.invalidRequest }
        return url
    }
}

public struct ProxyMeteoblueEndpoint: MeteoblueEndpointBuilding, Sendable {
    public let baseURL: URL

    public init(baseURL: URL) { self.baseURL = baseURL }

    public func requestURL(for location: WeatherLocation, apiKey: String) throws -> URL {
        guard location.coordinate.isValid else { throw WeatherServiceError.invalidRequest }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            .init(name: "lat", value: String(location.coordinate.latitude)),
            .init(name: "lon", value: String(location.coordinate.longitude)),
            .init(name: "tz", value: location.timeZoneIdentifier)
        ]
        guard let url = components?.url else { throw WeatherServiceError.invalidRequest }
        return url
    }
}
