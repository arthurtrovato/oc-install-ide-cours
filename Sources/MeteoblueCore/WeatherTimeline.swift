import Foundation

public struct WeatherTimeline: Equatable, Sendable {
    public let entries: [WeatherDisplayModel]
    public let requestedRefreshDate: Date

    public init(entries: [WeatherDisplayModel], requestedRefreshDate: Date) {
        self.entries = entries
        self.requestedRefreshDate = requestedRefreshDate
    }
}

public struct WeatherTimelineBuilder: Sendable {
    public let hourlyCount: Int
    public let dailyCount: Int
    public let futureEntryCount: Int
    public let refreshInterval: TimeInterval
    public let refreshPhase: TimeInterval
    public let hourlyCutoverMinutes: Int

    public init(
        hourlyCount: Int = 6,
        dailyCount: Int = 5,
        futureEntryCount: Int = 7,
        refreshInterval: TimeInterval = 90 * 60,
        refreshPhase: TimeInterval = 5 * 60,
        hourlyCutoverMinutes: Int = 5
    ) {
        self.hourlyCount = hourlyCount
        self.dailyCount = dailyCount
        self.futureEntryCount = futureEntryCount
        self.refreshInterval = max(15 * 60, refreshInterval)
        self.refreshPhase = refreshPhase
        self.hourlyCutoverMinutes = min(20, max(0, hourlyCutoverMinutes))
    }

    public func build(
        snapshot: WeatherSnapshot,
        from now: Date,
        isDifferentLocationFallback: Bool = false,
        warning: String? = nil
    ) -> WeatherTimeline {
        let zone = TimeZone(identifier: snapshot.location.timeZoneIdentifier) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone

        var dates = [now]
        if let nextHour = calendar.nextDate(after: now, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) {
            for offset in 0..<max(1, futureEntryCount) {
                guard let hourBoundary = calendar.date(byAdding: .hour, value: offset, to: nextHour) else { continue }
                dates.append(hourBoundary)
                if hourlyCutoverMinutes > 0,
                   let cutover = calendar.date(byAdding: .minute, value: hourlyCutoverMinutes, to: hourBoundary) {
                    dates.append(cutover)
                }
            }
        }

        dates.sort()
        var uniqueDates: [Date] = []
        for date in dates where uniqueDates.last != date {
            uniqueDates.append(date)
        }

        let entries = uniqueDates.map {
            displayModel(
                snapshot: snapshot,
                at: $0,
                calendar: calendar,
                isDifferentLocationFallback: isDifferentLocationFallback,
                warning: warning
            )
        }

        let cadence = WeatherRefreshCadence(interval: refreshInterval, phase: refreshPhase)
        let alignedRefresh = cadence.nextBoundary(after: now)
        let requestedRefresh = max(now.addingTimeInterval(15 * 60), alignedRefresh)
        return WeatherTimeline(entries: entries, requestedRefreshDate: requestedRefresh)
    }

    public func displayModel(
        snapshot: WeatherSnapshot,
        at date: Date,
        isDifferentLocationFallback: Bool = false,
        warning: String? = nil
    ) -> WeatherDisplayModel {
        let zone = TimeZone(identifier: snapshot.location.timeZoneIdentifier) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return displayModel(snapshot: snapshot, at: date, calendar: calendar, isDifferentLocationFallback: isDifferentLocationFallback, warning: warning)
    }

    private func displayModel(
        snapshot: WeatherSnapshot,
        at date: Date,
        calendar: Calendar,
        isDifferentLocationFallback: Bool,
        warning: String?
    ) -> WeatherDisplayModel {
        let tolerance = date.addingTimeInterval(-Double(hourlyCutoverMinutes) * 60)
        let hours = Array(snapshot.hourly.filter { $0.date > tolerance }.prefix(hourlyCount))
        let startOfDay = calendar.startOfDay(for: date)
        let days = Array(snapshot.daily.filter { calendar.startOfDay(for: $0.date) >= startOfDay }.prefix(dailyCount))
        return WeatherDisplayModel(
            date: date,
            snapshot: snapshot,
            current: snapshot.projectedCurrent(at: date),
            nextHours: hours,
            nextDays: days,
            freshness: snapshot.freshness(at: date, freshInterval: refreshInterval),
            isFallbackForDifferentLocation: isDifferentLocationFallback,
            warning: warning
        )
    }
}
