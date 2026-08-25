import MeteoblueCore
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        List {
            Section("Localisation") {
                row("Autorisation app", model.diagnostics.locationAuthorization)
                row("Autorisation widget", model.diagnostics.widgetLocationAuthorized ? "oui" : "non")
                row("Latitude / longitude", coordinateText)
                row("Precision", meters(model.diagnostics.locationAccuracyMeters))
                row("Age position", duration(model.diagnostics.locationAgeSeconds))
                row("Localite", model.diagnostics.displayedLocality ?? "-")
            }

            Section("meteoblue / cache") {
                row("Dernier appel", date(model.diagnostics.lastMeteoblueCall))
                row("Age cache", duration(model.diagnostics.cacheAgeSeconds))
                row("Source", model.diagnostics.cacheSource?.rawValue ?? "-")
                row("Prochaine demande", date(model.diagnostics.nextRequestedRefresh))
                row("Derniere erreur", model.diagnostics.lastError ?? "-")
            }

            Section("Application") {
                row("Version", model.diagnostics.appVersion)
                row("Deep link", model.diagnostics.deepLinkState)
            }

            Section {
                Button("Copier le diagnostic") { model.copyDiagnostic() }
            } footer: {
                Text("La copie masque explicitement la cle meteoblue et les parametres de type API key.")
            }
        }
        .navigationTitle("Diagnostics")
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) { Text(value).multilineTextAlignment(.trailing).foregroundStyle(.secondary) }
    }

    private var coordinateText: String {
        guard let c = model.diagnostics.lastCoordinate else { return "-" }
        return String(format: "%.5f, %.5f", c.latitude, c.longitude)
    }

    private func meters(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.0f m", value)
    }

    private func duration(_ value: TimeInterval?) -> String {
        guard let value else { return "-" }
        if value < 60 { return "\(Int(value)) s" }
        if value < 3600 { return "\(Int(value / 60)) min" }
        return String(format: "%.1f h", value / 3600)
    }

    private func date(_ value: Date?) -> String {
        guard let value else { return "-" }
        return value.formatted(date: .abbreviated, time: .standard)
    }
}
