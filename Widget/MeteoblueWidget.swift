import AppIntents
import Foundation
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

    private var tapURL: URL {
        entry.model?.snapshot.meteoblueURL ?? URL(string: "meteoblueweather://open-app")!
    }

    var body: some View {
        MeteoblueWidgetContent(model: entry.model, message: entry.message)
            .widgetURL(tapURL)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

private struct MeteoblueWidgetContent: View {
    let model: WeatherDisplayModel?
    let message: String?

    var body: some View {
        Group {
            if let model {
                WeatherBoard(model: model)
            } else {
                EmptyWeatherBoard(message: message ?? "Donnees indisponibles")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@available(iOS 27.0, *)
struct MeteoblueWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Action du widget Meteoblue" }
    static var description = IntentDescription(
        "Choisissez l’application à ouvrir quand vous touchez le widget."
    )

    @Parameter(title: "Action au toucher")
    var shortcut: SystemShortcut?
}

@available(iOS 27.0, *)
struct MeteoblueInteractiveWidgetEntry: TimelineEntry {
    let date: Date
    let model: WeatherDisplayModel?
    let message: String?
    let configuration: MeteoblueWidgetConfigurationIntent
}

@available(iOS 27.0, *)
struct MeteoblueInteractiveWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = MeteoblueInteractiveWidgetEntry

    func placeholder(in context: Context) -> Entry {
        let preview = PreviewWeather.entry(kind: .rain)
        return Entry(
            date: preview.date,
            model: preview.model,
            message: preview.message,
            configuration: MeteoblueWidgetConfigurationIntent()
        )
    }

    func snapshot(for configuration: MeteoblueWidgetConfigurationIntent, in context: Context) async -> Entry {
        if context.isPreview {
            let preview = PreviewWeather.entry(kind: .rain)
            return Entry(
                date: preview.date,
                model: preview.model,
                message: preview.message,
                configuration: configuration
            )
        }

        let result = await loadInteractiveWidgetData()
        if let model = result.timeline?.entries.first {
            return Entry(date: model.date, model: model, message: nil, configuration: configuration)
        }
        return Entry(date: Date(), model: nil, message: result.fallbackMessage, configuration: configuration)
    }

    func timeline(for configuration: MeteoblueWidgetConfigurationIntent, in context: Context) async -> Timeline<Entry> {
        let result = await loadInteractiveWidgetData()
        guard let weatherTimeline = result.timeline, !weatherTimeline.entries.isEmpty else {
            let retry = Date().addingTimeInterval(20 * 60)
            let entry = Entry(
                date: Date(),
                model: nil,
                message: result.fallbackMessage,
                configuration: configuration
            )
            return Timeline(entries: [entry], policy: .after(retry))
        }

        let entries = weatherTimeline.entries.map {
            Entry(date: $0.date, model: $0, message: nil, configuration: configuration)
        }
        return Timeline(entries: entries, policy: .after(weatherTimeline.requestedRefreshDate))
    }
}

@available(iOS 27.0, *)
@MainActor
private func loadInteractiveWidgetData() async -> (timeline: WeatherTimeline?, fallbackMessage: String) {
    let coordinator = WidgetWeatherCoordinator()
    let fallbackMessage: String
    if !coordinator.isConfigured {
        fallbackMessage = "Configurez la cle meteoblue dans l'app."
    } else if !coordinator.isWidgetLocationAuthorized {
        fallbackMessage = "Ouvrez l'app et autorisez la localisation pour le widget."
    } else {
        fallbackMessage = "Aucune donnee meteoblue disponible."
    }
    return (await coordinator.loadTimeline(), fallbackMessage)
}

@available(iOS 27.0, *)
private struct MeteoblueInteractiveWidgetView: View {
    let entry: MeteoblueInteractiveWidgetEntry

    var body: some View {
        Group {
            if let shortcut = entry.configuration.shortcut {
                Button(intent: RunSystemShortcutIntent(shortcut: shortcut)) {
                    MeteoblueWidgetContent(model: entry.model, message: entry.message)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ouvrir l’application Meteoblue")
            } else {
                MeteoblueWidgetContent(model: entry.model, message: entry.message)
                    .overlay {
                        VStack(spacing: 6) {
                            Spacer()
                            Text("Modifiez le widget et choisissez l’app Meteoblue dans « Action au toucher ».")
                                .font(.caption2.weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                        }
                    }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MeteoblueWidget: Widget {
    let kind = "MeteoblueWeatherWidget"

    var body: some WidgetConfiguration {
        makeWidgetConfiguration()
    }

    private func makeWidgetConfiguration() -> some WidgetConfiguration {
        if #available(iOS 27.0, *) {
            return makeInteractiveWidgetConfiguration()
        } else {
            return makeLegacyWidgetConfiguration()
        }
    }

    @available(iOS 27.0, *)
    private func makeInteractiveWidgetConfiguration() -> some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: MeteoblueWidgetConfigurationIntent.self,
            provider: MeteoblueInteractiveWidgetProvider()
        ) { entry in
            MeteoblueInteractiveWidgetView(entry: entry)
        }
        .configurationDisplayName("Meteoblue Weather")
        .description("Touchez le widget pour ouvrir directement l’application choisie.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }

    private func makeLegacyWidgetConfiguration() -> some WidgetConfiguration {
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
