import CoreLocation
import Foundation
import MeteoblueCore
import SwiftUI
import UIKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var displayModel: WeatherDisplayModel?
    @Published var isLoading = false
    @Published var statusMessage = "Initialisation…"
    @Published var diagnostics = DiagnosticsSnapshot()

    private let environment: AppleEnvironment
    private let locationClient: AppleLocationClient
    private let repository: WeatherRepository
    private let locationPolicy = LocationPolicy()
    private let timelineBuilder = WeatherTimelineBuilder()
    private var hasStarted = false

    init() {
        let environment = AppleEnvironment.make(namespace: "host")
        self.environment = environment
        self.locationClient = AppleLocationClient()
        let service = MeteoblueWeatherService(apiKeyProvider: { environment.configuration.meteoblueAPIKey })
        self.repository = WeatherRepository(service: service, cache: environment.cacheStore)
        self.diagnostics = DiagnosticsSnapshot(appVersion: Self.appVersion, deepLinkState: "Non testé")
    }

    var isConfigured: Bool { environment.configuration.isConfigured }
    var authorizationStatus: CLAuthorizationStatus { locationClient.authorizationStatus }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await refresh(promptForPermission: false, force: false)
    }

    func requestLocationPermission() {
        locationClient.requestWhenInUseAuthorization()
        statusMessage = "Autorisez la localisation « lors de l’utilisation de l’app ou des widgets », puis actualisez."
        updateAuthorizationDiagnostics()
    }

    func refresh(promptForPermission: Bool = false, force: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        updateAuthorizationDiagnostics()
        let now = Date()
        let previous = await environment.locationStore.load()
        let clLocation = await locationClient.requestCurrentLocation(promptIfNeeded: promptForPermission)
        let candidate = clLocation.map {
            LocationSample(
                coordinate: GeoCoordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude),
                timestamp: $0.timestamp,
                horizontalAccuracyMeters: $0.horizontalAccuracy
            )
        }

        let selected: LocationSample
        switch locationPolicy.decide(candidate: candidate, previous: previous, now: now) {
        case .accept(let sample, _):
            selected = sample
            await environment.locationStore.save(sample)
        case .retain(let sample, let reason):
            selected = sample
            statusMessage = locationFallbackMessage(reason)
        case .unavailable:
            diagnostics.lastError = "Aucune position valide et aucun historique local."
            statusMessage = authorizationStatus == .notDetermined
                ? "La localisation doit être autorisée pour configurer le widget."
                : "Aucune position valide n’est disponible."
            return
        }

        let location = await ApplePlacemarkResolver.weatherLocation(
            from: CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: selected.coordinate.latitude, longitude: selected.coordinate.longitude),
                altitude: 0,
                horizontalAccuracy: selected.horizontalAccuracyMeters,
                verticalAccuracy: -1,
                timestamp: selected.timestamp
            )
        )

        do {
            let result = try await repository.weather(for: location, at: now, forceRefresh: force)
            let timeline = timelineBuilder.build(
                snapshot: result.snapshot,
                from: now,
                isDifferentLocationFallback: result.isDifferentLocationFallback,
                warning: result.lastError
            )
            displayModel = timeline.entries.first
            statusMessage = status(for: result)
            diagnostics.lastCoordinate = selected.coordinate
            diagnostics.locationAccuracyMeters = selected.horizontalAccuracyMeters
            diagnostics.locationAgeSeconds = max(0, now.timeIntervalSince(selected.timestamp))
            diagnostics.displayedLocality = result.snapshot.location.locality
            diagnostics.lastMeteoblueCall = result.source == .network ? now : result.snapshot.fetchedAt
            diagnostics.cacheAgeSeconds = max(0, now.timeIntervalSince(result.snapshot.fetchedAt))
            diagnostics.nextRequestedRefresh = timeline.requestedRefreshDate
            diagnostics.lastError = result.lastError
            diagnostics.cacheSource = result.source
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            diagnostics.lastError = safeError(error)
            statusMessage = safeError(error)
        }
        updateAuthorizationDiagnostics()
    }

    func handleRelayURL(_ url: URL) {
        guard let target = MeteoblueForecastLinkBuilder.validatedTarget(from: url) else {
            diagnostics.deepLinkState = "Lien refusé (cible non autorisée)"
            return
        }
        diagnostics.deepLinkState = "Ouverture demandée : meteoblue HTTPS"
        UIApplication.shared.open(target, options: [:]) { [weak self] success in
            Task { @MainActor in
                self?.diagnostics.deepLinkState = success ? "Ouverture transmise à iOS" : "Échec d’ouverture par iOS"
            }
        }
    }

    func copyDiagnostic() {
        UIPasteboard.general.string = diagnostics.sanitizedText(additionalSecrets: [environment.configuration.meteoblueAPIKey].compactMap { $0 })
        statusMessage = "Diagnostic copié, sans clé API."
    }

    private func updateAuthorizationDiagnostics() {
        diagnostics.generatedAt = Date()
        diagnostics.locationAuthorization = locationClient.authorizationStatus.diagnosticValue
        diagnostics.widgetLocationAuthorized = locationClient.isAuthorizedForWidgetUpdates
        diagnostics.appVersion = Self.appVersion
    }

    private func status(for result: WeatherLoadResult) -> String {
        switch result.source {
        case .network: return "Données meteoblue actualisées."
        case .freshCache: return "Cache meteoblue frais — aucun appel inutile."
        case .staleCache: return "Hors ligne ou API indisponible — dernières données conservées."
        case .lastKnownFallback: return "Dernières données connues affichées pour éviter un widget vide."
        }
    }

    private func locationFallbackMessage(_ reason: LocationRejectionReason) -> String {
        switch reason {
        case .unavailable: return "GPS indisponible — dernière position valide utilisée."
        case .invalidCoordinate: return "Position invalide — dernière position valide utilisée."
        case .tooOld: return "Nouvelle position trop ancienne — dernière position valide utilisée."
        case .tooImprecise: return "Nouvelle position trop imprécise — dernière position valide utilisée."
        case .insignificantMovement: return "Déplacement inférieur à 20 km — zone météo conservée."
        }
    }

    private func safeError(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Erreur météo inattendue."
    }

    private static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}
