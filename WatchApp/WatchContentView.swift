import CoreLocation
import Foundation
import SwiftUI
import WidgetKit

struct WatchContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var authorizationStatus = CLLocationManager().authorizationStatus
    @State private var requesting = false
    @State private var openingWeather = false

    private var isConfigured: Bool {
        AppleEnvironment.make(namespace: "watch-app").configuration.isConfigured
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)

                Text("Meteoblue")
                    .font(.headline)

                Text("Complication rectangulaire")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Label(locationStatus, systemImage: authorizationStatus.allowsForegroundLocation ? "location.fill" : "location.slash")
                    .font(.caption2)
                    .multilineTextAlignment(.center)

                if authorizationStatus == .notDetermined {
                    Button(requesting ? "Activation…" : "Autoriser la localisation") {
                        requestLocationAuthorization()
                    }
                    .disabled(requesting)
                }

                Button {
                    openAppleWeather()
                } label: {
                    Label(openingWeather ? "Ouverture…" : "Ouvrir Météo", systemImage: "cloud.sun.fill")
                }
                .disabled(openingWeather)

                if !isConfigured {
                    Text("Clé meteoblue absente du build.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                } else if authorizationStatus.allowsForegroundLocation {
                    Text("Ajoutez Meteoblue dans l’emplacement rectangulaire central du cadran.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)
        }
        .task {
            authorizationStatus = CLLocationManager().authorizationStatus
        }
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "meteobluewatch",
                  url.host?.lowercased() == "apple-weather" else { return }
            openAppleWeather()
        }
    }

    private var locationStatus: String {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return "Localisation autorisée"
        case .denied: return "Localisation refusée"
        case .restricted: return "Localisation restreinte"
        case .notDetermined: return "Localisation à autoriser"
        @unknown default: return "État de localisation inconnu"
        }
    }

    private func requestLocationAuthorization() {
        requesting = true
        Task { @MainActor in
            let client = AppleLocationClient()
            authorizationStatus = await client.requestWhenInUseAuthorization()
            requesting = false
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func openAppleWeather() {
        guard !openingWeather else { return }
        openingWeather = true

        Task { @MainActor in
            let client = AppleLocationClient()
            let location = await client.requestCurrentLocation(promptIfNeeded: false)
            openURL(appleWeatherURL(for: location))
            openingWeather = false
        }
    }

    private func appleWeatherURL(for location: CLLocation?) -> URL {
        var components = URLComponents(string: "https://weather.apple.com/")!
        if let coordinate = location?.coordinate {
            components.queryItems = [
                URLQueryItem(name: "lat", value: String(format: "%.6f", coordinate.latitude)),
                URLQueryItem(name: "long", value: String(format: "%.6f", coordinate.longitude))
            ]
        }
        return components.url!
    }
}
