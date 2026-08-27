import Foundation

public struct DailyPrecipitationSummary: Equatable, Sendable {
    public let totalMillimeters: Double?
    public let timingAbbreviation: String?
    public let timingDescription: String?

    public init(totalMillimeters: Double?, timingAbbreviation: String?, timingDescription: String?) {
        self.totalMillimeters = totalMillimeters
        self.timingAbbreviation = timingAbbreviation
        self.timingDescription = timingDescription
    }
}

public extension WeatherDisplayModel {
    var todayPrecipitationSummary: DailyPrecipitationSummary {
        let targetDate = nextDays.first?.date ?? snapshot.daily.first?.date ?? date
        return precipitationSummary(for: targetDate)
    }

    func precipitationSummary(for date: Date) -> DailyPrecipitationSummary {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: snapshot.location.timeZoneIdentifier) ?? .current

        guard let day = calendar.dateInterval(of: .day, for: date) else {
            return DailyPrecipitationSummary(
                totalMillimeters: precipitationMillimeters(for: date),
                timingAbbreviation: nil,
                timingDescription: nil
            )
        }

        let hours = snapshot.hourly
            .filter { day.contains($0.date) }
            .sorted { $0.date < $1.date }

        let hourlyTotal = hours
            .compactMap(\.precipitationMillimeters)
            .filter { $0.isFinite && $0 > 0 }
            .reduce(0, +)

        let dailyTotal = precipitationMillimeters(for: date)
        let total: Double?
        if let dailyTotal, dailyTotal.isFinite, dailyTotal > 0 {
            total = dailyTotal
        } else if hourlyTotal > 0 {
            total = hourlyTotal
        } else {
            total = dailyTotal
        }

        let wetHours = hours.filter {
            guard let amount = $0.precipitationMillimeters else { return false }
            return amount.isFinite && amount >= 0.05
        }

        guard !wetHours.isEmpty else {
            return DailyPrecipitationSummary(
                totalMillimeters: total,
                timingAbbreviation: nil,
                timingDescription: nil
            )
        }

        let timing = PrecipitationTimingFormatter.summarize(wetHours, calendar: calendar)
        return DailyPrecipitationSummary(
            totalMillimeters: total,
            timingAbbreviation: timing.abbreviation,
            timingDescription: timing.description
        )
    }
}

private enum PrecipitationTimingFormatter {
    private struct Run {
        var hours: [HourlyForecast]
    }

    private struct TimingText {
        let abbreviation: String
        let description: String
    }

    static func summarize(_ wetHours: [HourlyForecast], calendar: Calendar) -> (abbreviation: String, description: String) {
        let runs = contiguousRuns(wetHours)
        let totalWetHours = wetHours.count

        // One or two isolated forecast hours benefit from exact ranges; longer periods
        // are easier to scan as short day-part labels on the Watch and iPhone widgets.
        if runs.count <= 2, totalWetHours <= 2 {
            let ranges = runs.map { exactRange($0, calendar: calendar) }
            let compact = ranges.map(\.compact).joined(separator: "/") + "h"
            let spoken = ranges.map(\.spoken).joined(separator: " et ")
            return (compact, spoken)
        }

        let semantic = semanticTiming(wetHours, calendar: calendar)
        return (semantic.abbreviation, semantic.description)
    }

    private static func contiguousRuns(_ hours: [HourlyForecast]) -> [Run] {
        var result: [Run] = []
        for hour in hours.sorted(by: { $0.date < $1.date }) {
            if let lastRun = result.last,
               let lastHour = lastRun.hours.last,
               hour.date.timeIntervalSince(lastHour.date) <= 90 * 60 {
                result[result.count - 1].hours.append(hour)
            } else {
                result.append(Run(hours: [hour]))
            }
        }
        return result
    }

    private static func exactRange(_ run: Run, calendar: Calendar) -> (compact: String, spoken: String) {
        let start = calendar.component(.hour, from: run.hours.first!.date)
        let last = calendar.component(.hour, from: run.hours.last!.date)
        let end = min(24, last + 1)
        return ("\(start)–\(end)", "de \(start) h à \(end) h")
    }

    private static func semanticTiming(_ hours: [HourlyForecast], calendar: Calendar) -> TimingText {
        let hourValues = hours.map { calendar.component(.hour, from: $0.date) }
        let detailed = orderedUnique(hourValues.map(detailedPart))

        if detailed.count == 1, let first = detailed.first {
            return TimingText(abbreviation: first.abbreviation, description: first.description)
        }

        let broad = orderedUnique(hourValues.map(broadPart))
        if broad.count == 1, let first = broad.first {
            return TimingText(abbreviation: first.abbreviation, description: first.description)
        }

        if broad.count == 2, hours.count < 12 {
            return TimingText(
                abbreviation: broad.map(\.abbreviation).joined(separator: "+"),
                description: broad.map(\.description).joined(separator: " et ")
            )
        }

        return TimingText(abbreviation: "tte j.", description: "toute la journée")
    }

    private struct DayPart: Equatable {
        let order: Int
        let abbreviation: String
        let description: String
    }

    private static func detailedPart(for hour: Int) -> DayPart {
        switch hour {
        case 5...7: return DayPart(order: 1, abbreviation: "d.mat.", description: "début de matinée")
        case 8...10: return DayPart(order: 2, abbreviation: "mat.", description: "matinée")
        case 11...12: return DayPart(order: 3, abbreviation: "f.mat.", description: "fin de matinée")
        case 13...15: return DayPart(order: 4, abbreviation: "d.ap.", description: "début d’après-midi")
        case 16...18: return DayPart(order: 5, abbreviation: "f.ap.", description: "fin d’après-midi")
        case 19...22: return DayPart(order: 6, abbreviation: "soir", description: "soirée")
        default: return DayPart(order: 0, abbreviation: "nuit", description: "nuit")
        }
    }

    private static func broadPart(for hour: Int) -> DayPart {
        switch hour {
        case 5...12: return DayPart(order: 1, abbreviation: "mat.", description: "matinée")
        case 13...18: return DayPart(order: 2, abbreviation: "ap.m.", description: "après-midi")
        case 19...22: return DayPart(order: 3, abbreviation: "soir", description: "soirée")
        default: return DayPart(order: 0, abbreviation: "nuit", description: "nuit")
        }
    }

    private static func orderedUnique(_ values: [DayPart]) -> [DayPart] {
        var seen = Set<String>()
        return values
            .sorted { $0.order < $1.order }
            .filter { seen.insert($0.abbreviation).inserted }
    }
}
