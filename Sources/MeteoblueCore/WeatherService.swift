import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum WeatherServiceError: Error, Equatable, LocalizedError {
    case missingAPIKey
    case invalidRequest
    case transportFailure
    case invalidHTTPResponse
    case httpStatus(Int)
    case emptyResponse
    case decodingFailure(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Clé API meteoblue absente."
        case .invalidRequest: return "La requête meteoblue n'a pas pu être créée."
        case .transportFailure: return "Connexion à meteoblue impossible."
        case .invalidHTTPResponse: return "Réponse HTTP meteoblue invalide."
        case .httpStatus(let status): return "meteoblue a répondu avec le statut HTTP \(status)."
        case .emptyResponse: return "meteoblue a renvoyé une réponse vide."
        case .decodingFailure(let message): return "Décodage meteoblue impossible : \(message)"
        }
    }
}

public protocol WeatherService: Sendable {
    func fetchWeather(for location: WeatherLocation, at date: Date) async throws -> WeatherSnapshot
}

public struct HTTPResult: Sendable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public protocol HTTPClient: Sendable {
    func get(_ url: URL) async throws -> HTTPResult
}

public struct URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL) async throws -> HTTPResult {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw WeatherServiceError.invalidHTTPResponse }
            return HTTPResult(data: data, statusCode: http.statusCode)
        } catch let error as WeatherServiceError {
            throw error
        } catch {
            throw WeatherServiceError.transportFailure
        }
    }
}

public struct MeteoblueWeatherService: WeatherService, Sendable {
    private let apiKeyProvider: @Sendable () -> String?
    private let endpoint: any MeteoblueEndpointBuilding
    private let httpClient: any HTTPClient

    public init(
        apiKeyProvider: @escaping @Sendable () -> String?,
        endpoint: any MeteoblueEndpointBuilding = DirectMeteoblueEndpoint(),
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.endpoint = endpoint
        self.httpClient = httpClient
    }

    public func fetchWeather(for location: WeatherLocation, at date: Date = Date()) async throws -> WeatherSnapshot {
        guard let key = apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw WeatherServiceError.missingAPIKey
        }
        let requestURL: URL
        do {
            requestURL = try endpoint.requestURL(for: location, apiKey: key)
        } catch WeatherServiceError.missingAPIKey {
            throw WeatherServiceError.missingAPIKey
        } catch {
            throw WeatherServiceError.invalidRequest
        }

        let result = try await httpClient.get(requestURL)
        guard (200..<300).contains(result.statusCode) else { throw WeatherServiceError.httpStatus(result.statusCode) }
        guard !result.data.isEmpty else { throw WeatherServiceError.emptyResponse }

        do {
            let payload = try MeteobluePayloadDecoder.decode(result.data)
            let forecastURL = try MeteoblueForecastLinkBuilder.webURL(for: location)
            return try MeteoblueTransformer.makeSnapshot(
                payload: payload,
                requestedLocation: location,
                fetchedAt: date,
                meteoblueURL: forecastURL
            )
        } catch let error as WeatherServiceError {
            throw error
        } catch {
            throw WeatherServiceError.decodingFailure(error.localizedDescription)
        }
    }
}

public struct MockWeatherService: WeatherService, Sendable {
    public enum Behavior: Sendable {
        case snapshot(WeatherSnapshot)
        case failure(WeatherServiceError)
    }

    public let behavior: Behavior

    public init(snapshot: WeatherSnapshot) { self.behavior = .snapshot(snapshot) }
    public init(error: WeatherServiceError) { self.behavior = .failure(error) }

    public func fetchWeather(for location: WeatherLocation, at date: Date) async throws -> WeatherSnapshot {
        switch behavior {
        case .snapshot(let snapshot): return snapshot
        case .failure(let error): throw error
        }
    }
}
