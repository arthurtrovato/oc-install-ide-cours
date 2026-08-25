import CoreLocation
import Foundation
import MeteoblueCore

@MainActor
final class WidgetWeatherCoordinator {
    private let environment: AppleEnvironment
    private let locationClient: AppleLocationClient
    private let repository: WeatherRepository
    private let locationPolicy = LocationPolicy()
    private let timelineBuilder = WeatherTimelineBuilder()

    init() {
        let environment = AppleEnvironment.make(namespace: "widget")
        self.environment = environment
        self.locationClient = AppleLocationClient()
        let service = MeteoblueWeatherService(apiKeyProvider: { environment.configuration.meteoblueAPIKey })
        self.repository = WeatherRepository(service: service, cache: environment.cacheStore)
    }

    func loadTimeline(at now: Date = Date()) async -> WeatherTimeline? {
        let previous = await environment.locationStore.load()
        let clLocation: CLLocation?
        if locationClient.isAuthorizedForWidgetUpdates {
            clLocation = await locationClient.requestCurrentLocation(promptIfNeeded: false)
        } else {
            clLocation = nil
        }

        let candidate = clLocation.map {
            LocationSample(
                coordinate: GeoCoordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude),
                timestamp: $0.timestamp,
                horizontalAccuracyMeters: $0.horizontalAccuracy
            )
        }

        let decision = locationPolicy.decide(candidate: candidate, previous: previous, now: now)
        let selected: LocationSample?
        let locationWarning: String?
        switch decision {
        case .accept(let sample, _):
            selected = sample
            locationWarning = nil
            await environment.locationStore.save(sample)
        case .retain(let sample, let reason):
            selected = sample
            locationWarning = warning(for: reason)
        case .unavailable:
            selected = nil
            locationWarning = "Localisation indisponible"
        }

        if let selected {
            let resolved = await ApplePlacemarkResolver.weatherLocation(
                from: CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: selected.coordinate.latitude, longitude: selected.coordinate.longitude),
                    altitude: 0,
                    horizontalAccuracy: selected.horizontalAccuracyMeters,
                    verticalAccuracy: -1,
                    timestamp: selected.timestamp
                )
            )
            do {
                let result = try await repository.weather(for: resolved, at: now, forceRefresh: false)
                let warning = result.lastError ?? locationWarning
                return timelineBuilder.build(
                    snapshot: result.snapshot,
                    from: now,
                    isDifferentLocationFallback: result.isDifferentLocationFallback,
                    warning: warning
                )
            } catch {
                if let cached = await repository.latestCachedWeather(at: now) {
                    return timelineBuilder.build(snapshot: cached.snapshot, from: now, warning: safeMessage(error))
                }
                return nil
            }
        }

        if let cached = await repository.latestCachedWeather(at: now) {
            return timelineBuilder.build(snapshot: cached.snapshot, from: now, warning: locationWarning)
        }
        return nil
    }

    var isConfigured: Bool { environment.configuration.isConfigured }
    var isWidgetLocationAuthorized: Bool { locationClient.isAuthorizedForWidgetUpdates }

    private func warning(for reason: LocationRejectionReason) -> String? {
        switch reason {
        case .insignificantMovement: return nil
        case .unavailable: return "Derniere position valide"
        case .invalidCoordinate: return "Position invalide: derniere zone conservee"
        case .tooOld: return "Position recente indisponible"
        case .tooImprecise: return "Position imprecise: derniere zone conservee"
        }
    }

    private func safeMessage(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Mise a jour indisponible"
    }
}
