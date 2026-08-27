import MeteoblueCore
import SwiftUI
import WidgetKit

struct MeteoblueWatchEntry: TimelineEntry {
    let date: Date
    let model: WeatherDisplayModel?
    let message: String?
}

struct MeteoblueWatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeteoblueWatchEntry {
        previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (MeteoblueWatchEntry) -> Void) {
        if context.isPreview {
            completion(previewEntry())
            return
        }
        Task { @MainActor in
            let coordinator = WidgetWeatherCoordinator(namespace: "watch-widget")
            if let timeline = await coordinator.loadTimeline(), let first = timeline.entries.first {
                completion(MeteoblueWatchEntry(date: first.date, model: first, message: nil))
            } else {
                completion(MeteoblueWatchEntry(date: Date(), model: nil, message: fallbackMessage(coordinator)))
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeteoblueWatchEntry>) -> Void) {
        Task { @MainActor in
            let coordinator = WidgetWeatherCoordinator(namespace: "watch-widget")
            guard let weatherTimeline = await coordinator.loadTimeline(), !weatherTimeline.entries.isEmpty else {
                let retry = Date().addingTimeInterval(20 * 60)
                let entry = MeteoblueWatchEntry(date: Date(), model: nil, message: fallbackMessage(coordinator))
                completion(Timeline(entries: [entry], policy: .after(retry)))
                return
            }
            let entries = weatherTimeline.entries.map {
                MeteoblueWatchEntry(date: $0.date, model: $0, message: nil)
            }
            completion(Timeline(entries: entries, policy: .after(weatherTimeline.requestedRefreshDate)))
        }
    }

    @MainActor
    private func fallbackMessage(_ coordinator: WidgetWeatherCoordinator) -> String {
        if !coordinator.isConfigured { return "Clé meteoblue absente" }
        if !coordinator.isWidgetLocationAuthorized { return "Ouvrez Meteoblue sur la Watch et autorisez la position" }
        return "Météo indisponible"
    }

    private func previewEntry() -> MeteoblueWatchEntry {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let start = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let location = WeatherLocation(
            coordinate: GeoCoordinate(latitude: 49.4, longitude: 5.98),
            locality: "Tressange",
            countryCode: "FR",
            timeZoneIdentifier: "Europe/Paris",
            elevationMeters: 320
        )
        let hourly = (0..<12).map { index -> HourlyForecast in
            let date = calendar.date(byAdding: .hour, value: index, to: start)!
            return HourlyForecast(
                date: date,
                temperatureCelsius: 16 + Double(index) * 0.5,
                condition: index < 3 ? .rain : .partlyCloudy,
                isDaylight: true,
                precipitationProbabilityPercent: index < 3 ? 80 : 15,
                precipitationMillimeters: index < 3 ? 0.6 : 0,
                sourcePictocode: index < 3 ? 23 : 7
            )
        }
        let dayStart = calendar.startOfDay(for: now)
        let daily = [DailyForecast(
            date: dayStart,
            minimumCelsius: 11,
            maximumCelsius: 22,
            condition: .rain,
            precipitationProbabilityPercent: 80,
            precipitationMillimeters: 2.4,
            sourcePictocode: 6
        )]
        let snapshot = WeatherSnapshot(
            fetchedAt: now,
            location: location,
            current: CurrentConditions(date: now, temperatureCelsius: 17, condition: .rain, isDaylight: true),
            hourly: hourly,
            daily: daily,
            meteoblueURL: try! MeteoblueForecastLinkBuilder.webURL(for: location)
        )
        let model = WeatherTimelineBuilder(hourlyCount: 6, dailyCount: 5).displayModel(snapshot: snapshot, at: now)
        return MeteoblueWatchEntry(date: now, model: model, message: nil)
    }
}

struct MeteoblueWatchWidgetView: View {
    let entry: MeteoblueWatchEntry

    var body: some View {
        Group {
            if let model = entry.model {
                WatchWeatherRectangularView(model: model)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "cloud.sun")
                    Text(entry.message ?? "Météo indisponible")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.65)
                        .lineLimit(2)
                }
            }
        }
        .widgetURL(URL(string: "meteobluewatch://apple-weather"))
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct MeteoblueWatchWidget: Widget {
    let kind = "MeteoblueWatchRectangular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeteoblueWatchProvider()) { entry in
            MeteoblueWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("Meteoblue 5 h")
        .description("Température actuelle, mini/maxi, pluie du jour et cinq prochaines heures.")
        .supportedFamilies([.accessoryRectangular])
        .contentMarginsDisabled()
    }
}

@main
struct MeteoblueWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        MeteoblueWatchWidget()
    }
}
