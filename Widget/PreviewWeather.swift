import MeteoblueCore
import SwiftUI
import WidgetKit

#if DEBUG
enum PreviewWeather {
    enum Kind { case rain, sun, snow, storm, fog, night }

    static func entry(kind: Kind) -> MeteoblueWidgetEntry {
        let snapshot = snapshot(kind: kind)
        let model = WeatherTimelineBuilder().displayModel(snapshot: snapshot, at: snapshot.fetchedAt)
        return MeteoblueWidgetEntry(date: model.date, model: model, message: nil)
    }

    static func snapshot(kind: Kind) -> WeatherSnapshot {
        let now = Date()
        let condition: WeatherCondition
        let temp: Double
        let locality: String
        switch kind {
        case .rain: condition = .rain; temp = 14; locality = "Tressange"
        case .sun: condition = .clear; temp = 31; locality = "Saint-Remy-en-Bouzemont-Saint-Genest-et-Isson"
        case .snow: condition = .snow; temp = -8; locality = "Chamonix-Mont-Blanc"
        case .storm: condition = .thunderstorm; temp = 24; locality = "Montpellier"
        case .fog: condition = .fog; temp = 5; locality = "Metz"
        case .night: condition = .clear; temp = 6; locality = "Tressange"
        }
        let location = WeatherLocation(coordinate: .init(latitude: 49.402, longitude: 5.982), locality: locality, countryCode: "FR", timeZoneIdentifier: "Europe/Paris", elevationMeters: 320)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let hourStart = calendar.dateInterval(of: .hour, for: now)!.start
        let hourly = (0..<12).map { index in
            let date = calendar.date(byAdding: .hour, value: index, to: hourStart)!
            return HourlyForecast(
                date: date,
                temperatureCelsius: temp + Double(index) * 0.7,
                condition: index < 4 ? condition : .partlyCloudy,
                isDaylight: kind == .night ? false : (7..<20).contains(calendar.component(.hour, from: date)),
                precipitationProbabilityPercent: condition == .clear ? 0 : Double(max(10, 80 - index * 8)),
                precipitationMillimeters: condition == .rain ? 0.7 : 0,
                sourcePictocode: nil
            )
        }
        let dayStart = calendar.startOfDay(for: now)
        let daily = (0..<7).map { index in
            DailyForecast(
                date: calendar.date(byAdding: .day, value: index, to: dayStart)!,
                minimumCelsius: temp - 3 + Double(index % 3),
                maximumCelsius: temp + 7 + Double(index % 5),
                condition: index == 0 ? condition : (index % 2 == 0 ? .partlyCloudy : .rain),
                precipitationProbabilityPercent: Double(index * 12),
                sourcePictocode: nil
            )
        }
        return WeatherSnapshot(
            fetchedAt: now,
            location: location,
            current: CurrentConditions(date: now, temperatureCelsius: temp, condition: condition, isDaylight: kind != .night, precipitationProbabilityPercent: condition == .clear ? 0 : 75),
            hourly: hourly,
            daily: daily,
            meteoblueURL: try! MeteoblueForecastLinkBuilder.webURL(for: location)
        )
    }
}

struct MeteoblueWidgetPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            MeteoblueWidgetView(entry: PreviewWeather.entry(kind: .rain))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Rain - light")
            MeteoblueWidgetView(entry: PreviewWeather.entry(kind: .sun))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .preferredColorScheme(.dark)
                .previewDisplayName("Sun - long city - dark")
            MeteoblueWidgetView(entry: PreviewWeather.entry(kind: .snow))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Snow - negative")
            MeteoblueWidgetView(entry: PreviewWeather.entry(kind: .storm))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .preferredColorScheme(.dark)
                .previewDisplayName("Storm")
            MeteoblueWidgetView(entry: PreviewWeather.entry(kind: .fog))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Fog")
            MeteoblueWidgetView(entry: PreviewWeather.entry(kind: .night))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .preferredColorScheme(.dark)
                .previewDisplayName("Clear night")
        }
    }
}
#else
enum PreviewWeather {
    enum Kind { case rain }
    static func entry(kind: Kind) -> MeteoblueWidgetEntry {
        MeteoblueWidgetEntry(date: Date(), model: nil, message: "Preview")
    }
}
#endif
