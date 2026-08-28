import CoreLocation
import SwiftUI
import WidgetKit

struct WatchContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var authorizationStatus = CLLocationManager().authorizationStatus
    @State private var requesting = false
    @State private var weatherLaunchFailed = false

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
                    Label("Ouvrir Météo", systemImage: "cloud.sun.fill")
                }

                if weatherLaunchFailed {
                    Text("Météo Apple n’a pas pu être ouverte automatiquement sur cette montre.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

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
        guard let weatherURL = URL(string: "weather://") else { return }
        weatherLaunchFailed = false
        openURL(weatherURL)
    }
}
