import Foundation

public struct MeteoblueMetadata: Equatable, Sendable {
    public let latitude: Double?
    public let longitude: Double?
    public let heightMeters: Double?
    public let timeZoneIdentifier: String?
    public let utcOffsetHours: Double?
    public let modelRunUTC: String?

    public init(latitude: Double?, longitude: Double?, heightMeters: Double?, timeZoneIdentifier: String?, utcOffsetHours: Double?, modelRunUTC: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.heightMeters = heightMeters
        self.timeZoneIdentifier = timeZoneIdentifier
        self.utcOffsetHours = utcOffsetHours
        self.modelRunUTC = modelRunUTC
    }
}

public struct MeteoblueHourlyData: Equatable, Sendable {
    public let time: [String]
    public let temperature: [Double?]
    public let pictocode: [Int?]
    public let isDaylight: [Bool?]
    public let precipitationProbability: [Double?]
    public let precipitation: [Double?]
}

public struct MeteoblueDailyData: Equatable, Sendable {
    public let time: [String]
    public let temperatureMinimum: [Double?]
    public let temperatureMaximum: [Double?]
    public let pictocode: [Int?]
    public let precipitationProbability: [Double?]
    public let precipitation: [Double?]
    public let sunrise: [String?]
    public let sunset: [String?]
}

public struct MeteoblueCurrentData: Equatable, Sendable {
    public let time: String?
    public let temperature: Double?
    public let pictocode: Int?
    public let detailedPictocode: Int?
    public let isDaylight: Bool?
    public let precipitationProbability: Double?
}

public struct MeteobluePayload: Equatable, Sendable {
    public let metadata: MeteoblueMetadata
    public let hourly: MeteoblueHourlyData?
    public let daily: MeteoblueDailyData?
    public let current: MeteoblueCurrentData?
}

public enum MeteobluePayloadError: Error, Equatable, LocalizedError {
    case malformedJSON
    case invalidTopLevel
    case noForecastData
    case noUsableHourlyData
    case noUsableDailyData

    public var errorDescription: String? {
        switch self {
        case .malformedJSON: return "La réponse meteoblue n'est pas un JSON valide."
        case .invalidTopLevel: return "La réponse meteoblue a une structure inattendue."
        case .noForecastData: return "La réponse meteoblue ne contient aucune prévision exploitable."
        case .noUsableHourlyData: return "Les prévisions horaires meteoblue sont incomplètes."
        case .noUsableDailyData: return "Les prévisions quotidiennes meteoblue sont incomplètes."
        }
    }
}

public enum MeteobluePayloadDecoder {
    public static func decode(_ data: Data) throws -> MeteobluePayload {
        let object: Any
        do { object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) }
        catch { throw MeteobluePayloadError.malformedJSON }
        guard let root = object as? [String: Any] else { throw MeteobluePayloadError.invalidTopLevel }

        let metadataDictionary = dictionary(root, keys: ["metadata", "meta"]) ?? [:]
        let metadata = MeteoblueMetadata(
            latitude: double(metadataDictionary, keys: ["latitude", "lat"]),
            longitude: double(metadataDictionary, keys: ["longitude", "lon"]),
            heightMeters: double(metadataDictionary, keys: ["height", "asl", "elevation"]),
            timeZoneIdentifier: string(metadataDictionary, keys: ["timezone", "time_zone", "timezone_identifier"]),
            utcOffsetHours: double(metadataDictionary, keys: ["utc_timeoffset", "utc_offset", "timezone_offset"]),
            modelRunUTC: string(metadataDictionary, keys: ["modelrun_utc", "model_run_utc"])
        )

        let hourly = dictionary(root, keys: ["data_1h", "data_hourly", "hourly"]).map { block in
            MeteoblueHourlyData(
                time: stringArray(block, keys: ["time", "timestamp"]),
                temperature: optionalDoubleArray(block, keys: ["temperature", "temperature_mean", "temperature_2m"]),
                pictocode: optionalIntArray(block, keys: ["pictocode_detailed", "pictocode", "weathercode"]),
                isDaylight: optionalBoolArray(block, keys: ["isdaylight", "is_daylight", "daylight"]),
                precipitationProbability: optionalDoubleArray(block, keys: ["precipitation_probability", "precipitation_probability_mean", "precipitation_probability_1h"]),
                precipitation: optionalDoubleArray(block, keys: ["precipitation", "precipitation_amount", "totalprecipitation"])
            )
        }

        let daily = dictionary(root, keys: ["data_day", "data_daily", "daily"]).map { block in
            MeteoblueDailyData(
                time: stringArray(block, keys: ["time", "date"]),
                temperatureMinimum: optionalDoubleArray(block, keys: ["temperature_min", "temperature_minimum", "temperature_2m_min"]),
                temperatureMaximum: optionalDoubleArray(block, keys: ["temperature_max", "temperature_maximum", "temperature_2m_max"]),
                pictocode: optionalIntArray(block, keys: ["pictocode", "weathercode"]),
                precipitationProbability: optionalDoubleArray(block, keys: ["precipitation_probability", "precipitation_probability_mean", "precipitation_probability_max"]),
                precipitation: optionalDoubleArray(block, keys: ["precipitation", "precipitation_amount", "precipitation_sum", "precipitation_total", "totalprecipitation"]),
                sunrise: optionalStringArray(block, keys: ["sunrise", "sunrise_time"]),
                sunset: optionalStringArray(block, keys: ["sunset", "sunset_time"])
            )
        }

        let current = dictionary(root, keys: ["data_current", "current"]).map { block in
            MeteoblueCurrentData(
                time: firstString(block, keys: ["time", "timestamp"]),
                temperature: firstDouble(block, keys: ["temperature", "temperature_mean", "temperature_2m"]),
                pictocode: firstInt(block, keys: ["pictocode", "weathercode"]),
                detailedPictocode: firstInt(block, keys: ["pictocode_detailed"]),
                isDaylight: firstBool(block, keys: ["isdaylight", "is_daylight", "daylight"]),
                precipitationProbability: firstDouble(block, keys: ["precipitation_probability", "precipitation_probability_mean"])
            )
        }

        guard hourly != nil || daily != nil || current != nil else { throw MeteobluePayloadError.noForecastData }
        return MeteobluePayload(metadata: metadata, hourly: hourly, daily: daily, current: current)
    }

    private static func dictionary(_ dictionary: [String: Any], keys: [String]) -> [String: Any]? {
        for key in keys { if let result = dictionary[key] as? [String: Any] { return result } }
        return nil
    }
    private static func string(_ dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys { if let value = dictionary[key] as? String, !value.isEmpty { return value } }
        return nil
    }
    private static func double(_ dictionary: [String: Any], keys: [String]) -> Double? {
        for key in keys { if let value = toDouble(dictionary[key]) { return value } }
        return nil
    }
    private static func integer(_ dictionary: [String: Any], keys: [String]) -> Int? {
        for key in keys { if let value = toInt(dictionary[key]) { return value } }
        return nil
    }
    private static func stringArray(_ dictionary: [String: Any], keys: [String]) -> [String] {
        optionalStringArray(dictionary, keys: keys).compactMap { $0 }
    }
    private static func optionalStringArray(_ dictionary: [String: Any], keys: [String]) -> [String?] {
        guard let values = firstArray(dictionary, keys: keys) else { return firstString(dictionary, keys: keys).map { [$0] } ?? [] }
        return values.map { value in
            if value is NSNull { return nil }
            if let string = value as? String { return string }
            return String(describing: value)
        }
    }
    private static func optionalDoubleArray(_ dictionary: [String: Any], keys: [String]) -> [Double?] {
        guard let values = firstArray(dictionary, keys: keys) else { return firstDouble(dictionary, keys: keys).map { [$0] } ?? [] }
        return values.map(toDouble)
    }
    private static func optionalIntArray(_ dictionary: [String: Any], keys: [String]) -> [Int?] {
        guard let values = firstArray(dictionary, keys: keys) else { return firstInt(dictionary, keys: keys).map { [$0] } ?? [] }
        return values.map(toInt)
    }
    private static func optionalBoolArray(_ dictionary: [String: Any], keys: [String]) -> [Bool?] {
        guard let values = firstArray(dictionary, keys: keys) else { return firstBool(dictionary, keys: keys).map { [$0] } ?? [] }
        return values.map(toBool)
    }
    private static func firstArray(_ dictionary: [String: Any], keys: [String]) -> [Any]? {
        for key in keys { if let values = dictionary[key] as? [Any] { return values } }
        return nil
    }
    private static func firstString(_ dictionary: [String: Any], keys: [String]) -> String? {
        if let array = firstArray(dictionary, keys: keys) { for value in array { if let string = value as? String { return string } } }
        return string(dictionary, keys: keys)
    }
    private static func firstDouble(_ dictionary: [String: Any], keys: [String]) -> Double? {
        if let array = firstArray(dictionary, keys: keys) { for value in array { if let result = toDouble(value) { return result } } }
        return double(dictionary, keys: keys)
    }
    private static func firstInt(_ dictionary: [String: Any], keys: [String]) -> Int? {
        if let array = firstArray(dictionary, keys: keys) { for value in array { if let result = toInt(value) { return result } } }
        return integer(dictionary, keys: keys)
    }
    private static func firstBool(_ dictionary: [String: Any], keys: [String]) -> Bool? {
        if let array = firstArray(dictionary, keys: keys) { for value in array { if let result = toBool(value) { return result } } }
        for key in keys { if let result = toBool(dictionary[key]) { return result } }
        return nil
    }
    private static func toDouble(_ value: Any?) -> Double? {
        if value == nil || value is NSNull { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
    private static func toInt(_ value: Any?) -> Int? {
        if value == nil || value is NSNull { return nil }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String, let double = Double(string) { return Int(double) }
        return nil
    }
    private static func toBool(_ value: Any?) -> Bool? {
        if value == nil || value is NSNull { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let string = value as? String {
            switch string.lowercased() {
            case "true", "yes", "day", "1": return true
            case "false", "no", "night", "0": return false
            default: return nil
            }
        }
        return nil
    }
}
