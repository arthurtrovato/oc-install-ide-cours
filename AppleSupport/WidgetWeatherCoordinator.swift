import CoreLocation
import Foundation
import MeteoblueCore
import OSLog

@MainActor
final class WidgetWeatherCoordinator {
    private let namespace: String
    private let environment: AppleEnvironment
    private let locationClient: AppleLocationClient
    private let repository: WeatherRepository
    private let locationPolicy = LocationPolicy()
    private let timelineBuilder = WeatherTimelineBuilder()
    private let logger = Logger(subsystem: "com.arthurtrovato.MeteoblueWidget", category: "weather-load")

    init(namespace: String = "widget") {
        let environment = AppleEnvironment.make(namespace: namespace)
        self.namespace = namespace
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
                return buildTimelineAndLog(result: result, at: now, warning: warning)
            } catch {
                if let cached = await repository.latestCachedWeather(at: now) {
                    return buildTimelineAndLog(result: cached, at: now, warning: safeMessage(error))
                }
                logger.error("METEOBLUE_SNAPSHOT surface=\(self.namespace, privacy: .public) result=unavailable")
                return nil
            }
        }

        if let cached = await repository.latestCachedWeather(at: now) {
            return buildTimelineAndLog(result: cached, at: now, warning: locationWarning)
        }
        logger.error("METEOBLUE_SNAPSHOT surface=\(self.namespace, privacy: .public) result=no-location-no-cache")
        return nil
    }

    var isConfigured: Bool { environment.configuration.isConfigured }
    var isWidgetLocationAuthorized: Bool { locationClient.isAuthorizedForWidgetUpdates }

    private func buildTimelineAndLog(result: WeatherLoadResult, at now: Date, warning: String?) -> WeatherTimeline {
        let timeline = timelineBuilder.build(
            snapshot: result.snapshot,
            from: now,
            isDifferentLocationFallback: result.isDifferentLocationFallback,
            warning: warning
        )
        let diagnostic = WeatherLoadDiagnostic(surface: namespace, result: result, timeline: timeline, observedAt: now)
        logger.info("\(diagnostic.logLine, privacy: .public)")
        return timeline
    }

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
