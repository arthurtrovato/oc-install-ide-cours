import Foundation

public enum MeteoblueTransformer {
    public static func makeSnapshot(
        payload: MeteobluePayload,
        requestedLocation: WeatherLocation,
        fetchedAt: Date,
        meteoblueURL: URL
    ) throws -> WeatherSnapshot {
        let timeZone = TimeZone(identifier: requestedLocation.timeZoneIdentifier) ?? .current
        let hourly = try makeHourly(payload.hourly, timeZone: timeZone)
        let daily = try makeDaily(payload.daily, timeZone: timeZone)
        let current = makeCurrent(payload.current, hourly: hourly, fetchedAt: fetchedAt, timeZone: timeZone)

        let coordinate: GeoCoordinate
        if let lat = payload.metadata.latitude, let lon = payload.metadata.longitude,
           GeoCoordinate(latitude: lat, longitude: lon).isValid {
            coordinate = GeoCoordinate(latitude: lat, longitude: lon)
        } else {
            coordinate = requestedLocation.coordinate
        }
        let location = WeatherLocation(
            coordinate: coordinate,
            locality: requestedLocation.locality,
            countryCode: requestedLocation.countryCode,
            timeZoneIdentifier: requestedLocation.timeZoneIdentifier,
            elevationMeters: payload.metadata.heightMeters ?? requestedLocation.elevationMeters
        )

        return WeatherSnapshot(
            fetchedAt: fetchedAt,
            modelRunUTC: payload.metadata.modelRunUTC,
            modelRunUpdateUTC: payload.metadata.modelRunUpdateUTC,
            location: location,
            current: current,
            hourly: hourly,
            daily: daily,
            meteoblueURL: meteoblueURL
        )
    }

    private static func makeHourly(_ block: MeteoblueHourlyData?, timeZone: TimeZone) throws -> [HourlyForecast] {
        guard let block, !block.time.isEmpty else { throw MeteobluePayloadError.noUsableHourlyData }
        var rows: [HourlyForecast] = []
        for index in block.time.indices {
            guard let date = parse(block.time[index], timeZone: timeZone), let temperature = value(block.temperature, at: index) else { continue }
            let code = value(block.pictocode, at: index)
            rows.append(HourlyForecast(
                date: date,
                temperatureCelsius: temperature,
                condition: MeteoblueConditionMapper.condition(for: code, set: .hourlyDetailed),
                isDaylight: value(block.isDaylight, at: index) ?? inferredDaylight(for: date, timeZone: timeZone),
                precipitationProbabilityPercent: clampedProbability(value(block.precipitationProbability, at: index)),
                precipitationMillimeters: value(block.precipitation, at: index),
                sourcePictocode: code
            ))
        }
        guard !rows.isEmpty else { throw MeteobluePayloadError.noUsableHourlyData }
        return rows.sorted { $0.date < $1.date }
    }

    private static func makeDaily(_ block: MeteoblueDailyData?, timeZone: TimeZone) throws -> [DailyForecast] {
        guard let block, !block.time.isEmpty else { throw MeteobluePayloadError.noUsableDailyData }
        var rows: [DailyForecast] = []
        for index in block.time.indices {
            guard let date = parse(block.time[index], timeZone: timeZone, daily: true),
                  let minimum = value(block.temperatureMinimum, at: index),
                  let maximum = value(block.temperatureMaximum, at: index) else { continue }
            let code = value(block.pictocode, at: index)
            rows.append(DailyForecast(
                date: date,
                minimumCelsius: min(minimum, maximum),
                maximumCelsius: max(minimum, maximum),
                condition: MeteoblueConditionMapper.condition(for: code, set: .daily),
                precipitationProbabilityPercent: clampedProbability(value(block.precipitationProbability, at: index)),
                precipitationMillimeters: nonnegative(value(block.precipitation, at: index)),
                sourcePictocode: code
            ))
        }
        guard !rows.isEmpty else { throw MeteobluePayloadError.noUsableDailyData }
        return rows.sorted { $0.date < $1.date }
    }

    private static func makeCurrent(_ block: MeteoblueCurrentData?, hourly: [HourlyForecast], fetchedAt: Date, timeZone: TimeZone) -> CurrentConditions {
        let nearest = hourly.min { abs($0.date.timeIntervalSince(fetchedAt)) < abs($1.date.timeIntervalSince(fetchedAt)) }
        let date = block?.time.flatMap { parse($0, timeZone: timeZone) } ?? fetchedAt
        let temperature = block?.temperature ?? nearest?.temperatureCelsius ?? 0
        let detailed = block?.detailedPictocode
        let daily = block?.pictocode
        let condition: WeatherCondition
        let sourceCode: Int?
        if let detailed {
            condition = MeteoblueConditionMapper.condition(for: detailed, set: .hourlyDetailed)
            sourceCode = detailed
        } else if let daily {
            condition = MeteoblueConditionMapper.condition(for: daily, set: .daily)
            sourceCode = daily
        } else {
            condition = nearest?.condition ?? .unknown
            sourceCode = nearest?.sourcePictocode
        }
        return CurrentConditions(
            date: date,
            temperatureCelsius: temperature,
            condition: condition,
            isDaylight: block?.isDaylight ?? nearest?.isDaylight ?? inferredDaylight(for: date, timeZone: timeZone),
            precipitationProbabilityPercent: clampedProbability(block?.precipitationProbability) ?? nearest?.precipitationProbabilityPercent,
            sourcePictocode: sourceCode
        )
    }

    private static func parse(_ raw: String, timeZone: TimeZone, daily: Bool = false) -> Date? {
        let candidates = daily
            ? ["yyyy-MM-dd", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss"]
            : ["yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssXXXXX"]
        for format in candidates {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = timeZone
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return ISO8601DateFormatter().date(from: raw)
    }

    private static func value<T>(_ values: [T?], at index: Int) -> T? {
        guard values.indices.contains(index) else { return nil }
        return values[index]
    }

    private static func clampedProbability(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(100, max(0, value))
    }

    private static func nonnegative(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func inferredDaylight(for date: Date, timeZone: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        return (7..<20).contains(hour)
    }
}
