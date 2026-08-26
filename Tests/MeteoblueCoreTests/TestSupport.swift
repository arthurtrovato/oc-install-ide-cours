import Foundation
@testable import MeteoblueCore

func utcDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

func localDate(_ value: String, zone: String = "Europe/Paris") -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(identifier: zone)!
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.date(from: value)!
}

func fixtureData(_ name: String) throws -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try Data(contentsOf: url)
}

enum SampleWeatherFactory {
    static func make(
        locality: String = "Tressange",
        condition: WeatherCondition = .rain,
        fetchedAt: Date = utcDate("2026-08-25T08:00:00Z"),
        zone: String = "Europe/Paris",
        coordinate: GeoCoordinate = .init(latitude: 49.402, longitude: 5.982),
        temperature: Double = 14
    ) -> WeatherSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .current
        let localStart = calendar.dateInterval(of: .hour, for: fetchedAt)?.start ?? fetchedAt
        let hourly = (0..<48).map { index in
            HourlyForecast(
                date: calendar.date(byAdding: .hour, value: index, to: localStart)!,
                temperatureCelsius: temperature + Double(index % 8),
                condition: index % 5 == 0 ? condition : .partlyCloudy,
                isDaylight: (7..<20).contains(calendar.component(.hour, from: calendar.date(byAdding: .hour, value: index, to: localStart)!)),
                precipitationProbabilityPercent: Double((index * 13) % 100),
                precipitationMillimeters: index % 3 == 0 ? 0.8 : 0,
                sourcePictocode: condition == .rain ? 23 : 7
            )
        }
        let dayStart = calendar.startOfDay(for: fetchedAt)
        var daily: [DailyForecast] = []
        for index in 0..<7 {
            let dayDate = calendar.date(byAdding: .day, value: index, to: dayStart)!
            let minTemp = temperature - 2.0 + Double(index)
            let maxTemp = temperature + 8.0 + Double(index)
            let dayCondition: WeatherCondition = index % 2 == 0 ? condition : .partlyCloudy
            let probability = Double(20 + index * 10)
            let code = condition == .rain ? 6 : 3
            daily.append(DailyForecast(date: dayDate, minimumCelsius: minTemp, maximumCelsius: maxTemp, condition: dayCondition, precipitationProbabilityPercent: probability, precipitationMillimeters: index.isMultiple(of: 2) ? 1.4 : 0, sourcePictocode: code))
        }
        let location = WeatherLocation(
            coordinate: coordinate,
            locality: locality,
            countryCode: "FR",
            timeZoneIdentifier: zone,
            elevationMeters: 320
        )
        return WeatherSnapshot(
            fetchedAt: fetchedAt,
            location: location,
            current: CurrentConditions(
                date: fetchedAt,
                temperatureCelsius: temperature,
                condition: condition,
                isDaylight: true,
                precipitationProbabilityPercent: 70,
                sourcePictocode: 23
            ),
            hourly: hourly,
            daily: daily,
            meteoblueURL: try! MeteoblueForecastLinkBuilder.webURL(for: location)
        )
    }
}

actor InMemoryWeatherCacheStore: WeatherCacheStore {
    private var records: [WeatherCacheRecord]

    init(records: [WeatherCacheRecord] = []) { self.records = records }

    func loadRecords() async throws -> [WeatherCacheRecord] { records }
    func saveRecords(_ records: [WeatherCacheRecord]) async throws { self.records = records }
}

struct CountingWeatherService: WeatherService, @unchecked Sendable {
    final class Counter: @unchecked Sendable {
        private var value = 0
        private let lock = NSLock()
        func increment() { lock.lock(); value += 1; lock.unlock() }
        func read() -> Int { lock.lock(); defer { lock.unlock() }; return value }
    }

    let counter: Counter
    let result: Result<WeatherSnapshot, WeatherServiceError>

    func fetchWeather(for location: WeatherLocation, at date: Date) async throws -> WeatherSnapshot {
        counter.increment()
        return try result.get()
    }
}

struct StubHTTPClient: HTTPClient, Sendable {
    let result: Result<HTTPResult, WeatherServiceError>
    func get(_ url: URL) async throws -> HTTPResult { try result.get() }
}
