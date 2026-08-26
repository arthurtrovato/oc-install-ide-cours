import Foundation

public struct GeoCoordinate: Codable, Equatable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    public func distanceKilometers(to other: GeoCoordinate) -> Double {
        let radius = 6_371.0088
        let p1 = latitude * .pi / 180
        let p2 = other.latitude * .pi / 180
        let dp = (other.latitude - latitude) * .pi / 180
        let dl = (other.longitude - longitude) * .pi / 180
        let a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return radius * 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
    }
}

public struct WeatherLocation: Codable, Equatable, Hashable, Sendable {
    public let coordinate: GeoCoordinate
    public let locality: String
    public let countryCode: String?
    public let timeZoneIdentifier: String
    public let elevationMeters: Double?

    public init(
        coordinate: GeoCoordinate,
        locality: String,
        countryCode: String? = nil,
        timeZoneIdentifier: String,
        elevationMeters: Double? = nil
    ) {
        self.coordinate = coordinate
        self.locality = locality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Position actuelle" : locality
        self.countryCode = countryCode
        self.timeZoneIdentifier = TimeZone(identifier: timeZoneIdentifier) == nil ? TimeZone.current.identifier : timeZoneIdentifier
        self.elevationMeters = elevationMeters
    }
}

public enum WeatherFreshness: String, Codable, Equatable, Sendable {
    case fresh
    case stale
    case veryStale
}

public struct CurrentConditions: Codable, Equatable, Sendable {
    public let date: Date
    public let temperatureCelsius: Double
    public let condition: WeatherCondition
    public let isDaylight: Bool
    public let precipitationProbabilityPercent: Double?
    public let sourcePictocode: Int?

    public init(
        date: Date,
        temperatureCelsius: Double,
        condition: WeatherCondition,
        isDaylight: Bool,
        precipitationProbabilityPercent: Double? = nil,
        sourcePictocode: Int? = nil
    ) {
        self.date = date
        self.temperatureCelsius = temperatureCelsius
        self.condition = condition
        self.isDaylight = isDaylight
        self.precipitationProbabilityPercent = precipitationProbabilityPercent
        self.sourcePictocode = sourcePictocode
    }
}

public struct HourlyForecast: Codable, Equatable, Sendable {
    public let date: Date
    public let temperatureCelsius: Double
    public let condition: WeatherCondition
    public let isDaylight: Bool
    public let precipitationProbabilityPercent: Double?
    public let precipitationMillimeters: Double?
    public let sourcePictocode: Int?

    public init(
        date: Date,
        temperatureCelsius: Double,
        condition: WeatherCondition,
        isDaylight: Bool,
        precipitationProbabilityPercent: Double? = nil,
        precipitationMillimeters: Double? = nil,
        sourcePictocode: Int? = nil
    ) {
        self.date = date
        self.temperatureCelsius = temperatureCelsius
        self.condition = condition
        self.isDaylight = isDaylight
        self.precipitationProbabilityPercent = precipitationProbabilityPercent
        self.precipitationMillimeters = precipitationMillimeters
        self.sourcePictocode = sourcePictocode
    }
}

public struct DailyForecast: Codable, Equatable, Sendable {
    public let date: Date
    public let minimumCelsius: Double
    public let maximumCelsius: Double
    public let condition: WeatherCondition
    public let precipitationProbabilityPercent: Double?
    public let precipitationMillimeters: Double?
    public let sourcePictocode: Int?

    public init(
        date: Date,
        minimumCelsius: Double,
        maximumCelsius: Double,
        condition: WeatherCondition,
        precipitationProbabilityPercent: Double? = nil,
        precipitationMillimeters: Double? = nil,
        sourcePictocode: Int? = nil
    ) {
        self.date = date
        self.minimumCelsius = minimumCelsius
        self.maximumCelsius = maximumCelsius
        self.condition = condition
        self.precipitationProbabilityPercent = precipitationProbabilityPercent
        self.precipitationMillimeters = precipitationMillimeters
        self.sourcePictocode = sourcePictocode
    }
}

public struct WeatherSnapshot: Codable, Equatable, Sendable {
    public let fetchedAt: Date
    public let location: WeatherLocation
    public let current: CurrentConditions
    public let hourly: [HourlyForecast]
    public let daily: [DailyForecast]
    public let meteoblueURL: URL

    public init(
        fetchedAt: Date,
        location: WeatherLocation,
        current: CurrentConditions,
        hourly: [HourlyForecast],
        daily: [DailyForecast],
        meteoblueURL: URL
    ) {
        self.fetchedAt = fetchedAt
        self.location = location
        self.current = current
        self.hourly = hourly.sorted { $0.date < $1.date }
        self.daily = daily.sorted { $0.date < $1.date }
        self.meteoblueURL = meteoblueURL
    }

    public func freshness(at date: Date, freshInterval: TimeInterval = 75 * 60, veryStaleInterval: TimeInterval = 6 * 60 * 60) -> WeatherFreshness {
        let age = max(0, date.timeIntervalSince(fetchedAt))
        if age <= freshInterval { return .fresh }
        if age <= veryStaleInterval { return .stale }
        return .veryStale
    }

    public func projectedCurrent(at date: Date) -> CurrentConditions {
        guard !hourly.isEmpty else { return current }
        let nearest = hourly.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        guard let nearest, abs(nearest.date.timeIntervalSince(date)) <= 90 * 60 else { return current }
        return CurrentConditions(
            date: date,
            temperatureCelsius: nearest.temperatureCelsius,
            condition: nearest.condition,
            isDaylight: nearest.isDaylight,
            precipitationProbabilityPercent: nearest.precipitationProbabilityPercent,
            sourcePictocode: nearest.sourcePictocode
        )
    }
}

public struct WeatherDisplayModel: Codable, Equatable, Sendable {
    public let date: Date
    public let snapshot: WeatherSnapshot
    public let current: CurrentConditions
    public let nextHours: [HourlyForecast]
    public let nextDays: [DailyForecast]
    public let freshness: WeatherFreshness
    public let isFallbackForDifferentLocation: Bool
    public let warning: String?

    public init(
        date: Date,
        snapshot: WeatherSnapshot,
        current: CurrentConditions,
        nextHours: [HourlyForecast],
        nextDays: [DailyForecast],
        freshness: WeatherFreshness,
        isFallbackForDifferentLocation: Bool = false,
        warning: String? = nil
    ) {
        self.date = date
        self.snapshot = snapshot
        self.current = current
        self.nextHours = nextHours
        self.nextDays = nextDays
        self.freshness = freshness
        self.isFallbackForDifferentLocation = isFallbackForDifferentLocation
        self.warning = warning
    }

    public var todayMinimumCelsius: Double? { nextDays.first?.minimumCelsius ?? snapshot.daily.first?.minimumCelsius }
    public var todayMaximumCelsius: Double? { nextDays.first?.maximumCelsius ?? snapshot.daily.first?.maximumCelsius }
    public var todayPrecipitationMillimeters: Double? {
        guard let day = nextDays.first ?? snapshot.daily.first else { return nil }
        return precipitationMillimeters(for: day.date)
    }

    public func precipitationMillimeters(for date: Date) -> Double? {
        let calendar = weatherCalendar
        if let daily = snapshot.daily.first(where: { calendar.isDate($0.date, inSameDayAs: date) }),
           let value = daily.precipitationMillimeters,
           value.isFinite {
            return max(0, value)
        }

        guard let interval = calendar.dateInterval(of: .day, for: date) else { return nil }
        let hourlyValues = snapshot.hourly
            .filter { interval.contains($0.date) }
            .compactMap(\.precipitationMillimeters)
            .filter { $0.isFinite && $0 > 0 }
        guard !hourlyValues.isEmpty else {
            return snapshot.hourly.contains { interval.contains($0.date) } ? 0 : nil
        }
        return hourlyValues.reduce(0, +)
    }

    private var weatherCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: snapshot.location.timeZoneIdentifier) ?? .current
        return calendar
    }
}
