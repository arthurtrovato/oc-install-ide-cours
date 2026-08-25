import Foundation

public enum WeatherCondition: String, Codable, CaseIterable, Equatable, Sendable {
    case clear
    case mostlyClear
    case partlyCloudy
    case overcast
    case fog
    case haze
    case rain
    case showers
    case thunderstorm
    case snow
    case snowShowers
    case sleet
    case unknown

    public var frenchName: String {
        switch self {
        case .clear: return "Ciel clair"
        case .mostlyClear: return "Peu nuageux"
        case .partlyCloudy: return "Partiellement nuageux"
        case .overcast: return "Couvert"
        case .fog: return "Brouillard"
        case .haze: return "Brume"
        case .rain: return "Pluie"
        case .showers: return "Averses"
        case .thunderstorm: return "Orage"
        case .snow: return "Neige"
        case .snowShowers: return "Averses de neige"
        case .sleet: return "Pluie et neige"
        case .unknown: return "Variable"
        }
    }

    public func sfSymbolName(isDaylight: Bool) -> String {
        switch self {
        case .clear: return isDaylight ? "sun.max.fill" : "moon.stars.fill"
        case .mostlyClear: return isDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
        case .partlyCloudy: return isDaylight ? "cloud.sun.fill" : "cloud.moon.fill"
        case .overcast: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .haze: return isDaylight ? "sun.haze.fill" : "moon.haze.fill"
        case .rain: return "cloud.rain.fill"
        case .showers: return "cloud.heavyrain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow, .snowShowers: return "cloud.snow.fill"
        case .sleet: return "cloud.sleet.fill"
        case .unknown: return "cloud.fill"
        }
    }
}

public enum MeteobluePictocodeSet: Sendable {
    case daily
    case hourlyDetailed
}

public enum MeteoblueConditionMapper {
    public static func condition(for pictocode: Int?, set: MeteobluePictocodeSet) -> WeatherCondition {
        guard let pictocode else { return .unknown }
        switch set {
        case .daily:
            switch pictocode {
            case 1: return .clear
            case 2: return .mostlyClear
            case 3: return .partlyCloudy
            case 4: return .overcast
            case 5: return .fog
            case 6, 12, 14, 16: return .rain
            case 7: return .showers
            case 8: return .thunderstorm
            case 9, 13, 15, 17: return .snow
            case 10: return .snowShowers
            case 11: return .sleet
            default: return .unknown
            }
        case .hourlyDetailed:
            switch pictocode {
            case 1, 2, 3: return .clear
            case 4, 5, 6: return .mostlyClear
            case 7, 8, 9: return .partlyCloudy
            case 10, 11, 12: return .thunderstorm
            case 13, 14, 15: return .haze
            case 16, 17, 18: return .fog
            case 19, 20, 21, 22: return .overcast
            case 23, 25, 33: return .rain
            case 24, 26, 34: return .snow
            case 27, 28, 30: return .thunderstorm
            case 29: return .snow
            case 31: return .showers
            case 32: return .snowShowers
            case 35: return .sleet
            default: return .unknown
            }
        }
    }
}
