import CoreLocation
import Foundation
import MeteoblueCore

@MainActor
final class WidgetWeatherCoordinator {
    private let environment: AppleEnvironment
    private let locationClient: AppleLocationClient
    private let repository: WeatherRepository
    private let locationPolicy = LocationPolicy()
    private let timelineBuilder = WeatherTimelineBuilder(hourlyCount: 6, dailyCount: 5)

    init() {
        let environment = AppleEnvironment.make(namespace: "watch-widget")
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
        switch decision {
        case .accept(let sample, _):
            selected = sample
            await environment.locationStore.save(sample)
        case .retain(let sample, _):
            selected = sample
        case .unavailable:
            selected = nil
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
                return timelineBuilder.build(
                    snapshot: result.snapshot,
                    from: now,
                    isDifferentLocationFallback: result.isDifferentLocationFallback,
                    warning: result.lastError
                )
            } catch {
                if let cached = await repository.latestCachedWeather(at: now) {
                    return timelineBuilder.build(snapshot: cached.snapshot, from: now)
                }
                return nil
            }
        }

        if let cached = await repository.latestCachedWeather(at: now) {
            return timelineBuilder.build(snapshot: cached.snapshot, from: now)
        }
        return nil
    }

    var isConfigured: Bool { environment.configuration.isConfigured }
    var isWidgetLocationAuthorized: Bool { locationClient.isAuthorizedForWidgetUpdates }
}
