import SwiftUI
import WidgetKit
import MeteoblueCore

struct MeteoblueWidgetEntry: TimelineEntry {
    let date: Date
    let model: WeatherDisplayModel?
    let message: String?
}

struct MeteoblueWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeteoblueWidgetEntry {
        PreviewWeather.entry(kind: .rain)
    }

    func getSnapshot(in context: Context, completion: @escaping (MeteoblueWidgetEntry) -> Void) {
        if context.isPreview {
            completion(PreviewWeather.entry(kind: .rain))
            return
        }
        Task { @MainActor in
            let coordinator = WidgetWeatherCoordinator()
            if let timeline = await coordinator.loadTimeline(), let first = timeline.entries.first {
                completion(MeteoblueWidgetEntry(date: first.date, model: first, message: nil))
            } else {
                completion(MeteoblueWidgetEntry(date: Date(), model: nil, message: fallbackMessage(coordinator: coordinator)))
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeteoblueWidgetEntry>) -> Void) {
        Task { @MainActor in
            let coordinator = WidgetWeatherCoordinator()
            guard let weatherTimeline = await coordinator.loadTimeline(), !weatherTimeline.entries.isEmpty else {
                let retry = Date().addingTimeInterval(20 * 60)
                let entry = MeteoblueWidgetEntry(date: Date(), model: nil, message: fallbackMessage(coordinator: coordinator))
                completion(Timeline(entries: [entry], policy: .after(retry)))
                return
            }
            let entries = weatherTimeline.entries.map { MeteoblueWidgetEntry(date: $0.date, model: $0, message: nil) }
            completion(Timeline(entries: entries, policy: .after(weatherTimeline.requestedRefreshDate)))
        }
    }

    @MainActor
    private func fallbackMessage(coordinator: WidgetWeatherCoordinator) -> String {
        if !coordinator.isConfigured { return "Configurez la cle meteoblue dans l'app." }
        if !coordinator.isWidgetLocationAuthorized { return "Ouvrez l'app et autorisez la localisation pour le widget." }
        return "Aucune donnee meteoblue disponible. Touchez pour ouvrir l'app."
    }
}

struct MeteoblueWidgetView: View {
    let entry: MeteoblueWidgetEntry

    var body: some View {
        Group {
            if let model = entry.model {
                WeatherBoard(model: model)
                    .widgetURL(try? MeteoblueForecastLinkBuilder.relayURL(for: model.snapshot.meteoblueURL))
            } else {
                EmptyWeatherBoard(message: entry.message ?? "Donnees indisponibles")
                    .widgetURL(URL(string: "meteoblueweather://open-app"))
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MeteoblueWidget: Widget {
    let kind = "MeteoblueWeatherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeteoblueWidgetProvider()) { entry in
            MeteoblueWidgetView(entry: entry)
        }
        .configurationDisplayName("Meteoblue Weather")
        .description("Meteo actuelle, six prochaines heures et cinq prochains jours via meteoblue.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct MeteoblueWidgetBundle: WidgetBundle {
    var body: some Widget { MeteoblueWidget() }
}
