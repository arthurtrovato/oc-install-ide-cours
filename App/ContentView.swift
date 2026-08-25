import CoreLocation
import MeteoblueCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List {
            Section("Configuration") {
                LabeledContent("API meteoblue") {
                    Label(model.isConfigured ? "Configuree" : "Cle absente", systemImage: model.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(model.isConfigured ? .green : .orange)
                }
                LabeledContent("Localisation") {
                    Text(model.authorizationStatus.diagnosticValue)
                        .foregroundStyle(.secondary)
                }
                if model.authorizationStatus == .notDetermined {
                    Button("Autoriser la localisation") { model.requestLocationPermission() }
                } else if model.authorizationStatus == .denied || model.authorizationStatus == .restricted {
                    Text("Autorisez la localisation dans Reglages pour que l'app et le widget suivent vos deplacements.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let weather = model.displayModel {
                Section("Meteo meteoblue") {
                    CurrentSummaryView(model: weather)
                    if weather.freshness != .fresh {
                        Label(weather.freshness == .veryStale ? "Donnees tres anciennes" : "Donnees en cache", systemImage: "clock.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Etat") {
                Text(model.statusMessage)
                    .font(.callout)
                Button {
                    Task { await model.refresh(force: true) }
                } label: {
                    Label(model.isLoading ? "Actualisation..." : "Actualiser", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
            }

            Section("Widget") {
                Text("Ajoutez le grand widget 'Meteoblue Weather' depuis l'ecran d'accueil. iOS demandera si l'autorisation de localisation de l'app peut aussi s'appliquer au widget.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink("Diagnostics") {
                    DiagnosticsView(model: model)
                }
            }
        }
        .navigationTitle("Meteoblue Weather")
    }
}

private struct CurrentSummaryView: View {
    let model: WeatherDisplayModel

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: model.current.condition.sfSymbolName(isDaylight: model.current.isDaylight))
                .font(.system(size: 34))
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.snapshot.location.locality)
                    .font(.headline)
                    .lineLimit(1)
                Text(model.current.condition.frenchName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(model.current.temperatureCelsius.rounded())) deg")
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
