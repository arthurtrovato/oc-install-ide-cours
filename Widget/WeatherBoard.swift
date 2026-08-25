import MeteoblueCore
import SwiftUI

struct WeatherBoard: View {
    let model: WeatherDisplayModel

    var body: some View {
        VStack(spacing: 7) {
            header
            currentRow
            Divider().opacity(0.35)
            hourlyRow
            Divider().opacity(0.35)
            dailyRows
        }
        .padding(14)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(model.snapshot.location.locality)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
            Spacer(minLength: 6)
            if model.freshness != .fresh || model.isFallbackForDifferentLocation {
                Label(staleLabel, systemImage: "clock")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var currentRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(temperature(model.current.temperatureCelsius))
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: model.current.condition.sfSymbolName(isDaylight: model.current.isDaylight))
                        .symbolRenderingMode(.hierarchical)
                    Text(model.current.condition.frenchName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.subheadline.weight(.semibold))
                Text("H \(temperature(model.todayMaximumCelsius))  B \(temperature(model.todayMinimumCelsius))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var hourlyRow: some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(Array(model.nextHours.prefix(6).enumerated()), id: \.offset) { _, hour in
                VStack(spacing: 3) {
                    Text(hourLabel(hour.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: hour.condition.sfSymbolName(isDaylight: hour.isDaylight))
                        .font(.system(size: 16))
                        .symbolRenderingMode(.hierarchical)
                        .frame(height: 19)
                    Text(temperature(hour.temperatureCelsius))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    if let probability = hour.precipitationProbabilityPercent, probability >= 10 {
                        Text("\(Int(probability.rounded()))%")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        Text(" ").font(.system(size: 8))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var dailyRows: some View {
        VStack(spacing: 4) {
            ForEach(Array(model.nextDays.prefix(5).enumerated()), id: \.offset) { index, day in
                DailyForecastRow(day: day, allDays: Array(model.nextDays.prefix(5)), isToday: index == 0)
            }
        }
    }

    private var staleLabel: String {
        if model.isFallbackForDifferentLocation { return "ancienne zone" }
        let age = max(0, model.date.timeIntervalSince(model.snapshot.fetchedAt))
        if age < 120 * 60 { return "cache" }
        return "\(Int(age / 3600)) h"
    }

    private func hourLabel(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: model.snapshot.location.timeZoneIdentifier) ?? .current
        let hour = calendar.component(.hour, from: date)
        return String(format: "%02d h", hour)
    }

    private func temperature(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))°"
    }
}

private struct DailyForecastRow: View {
    let day: DailyForecast
    let allDays: [DailyForecast]
    let isToday: Bool

    var body: some View {
        HStack(spacing: 7) {
            Text(weekday(day.date))
                .font(.caption.weight(isToday ? .bold : .semibold))
                .frame(width: 34, alignment: .leading)
            Image(systemName: day.condition.sfSymbolName(isDaylight: true))
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 14))
                .frame(width: 20)
            Text(temp(day.minimumCelsius))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
            TemperatureRangeBar(day: day, allDays: allDays)
                .frame(height: 7)
            Text(temp(day.maximumCelsius))
                .font(.caption.weight(.semibold).monospacedDigit())
                .frame(width: 34, alignment: .trailing)
        }
        .frame(height: 22)
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = isToday ? "'Auj.'" : "EEE"
        return formatter.string(from: date).capitalized
    }

    private func temp(_ value: Double) -> String { "\(Int(value.rounded()))°" }
}

private struct TemperatureRangeBar: View {
    let day: DailyForecast
    let allDays: [DailyForecast]

    var body: some View {
        GeometryReader { proxy in
            let globalMin = allDays.map(\.minimumCelsius).min() ?? day.minimumCelsius
            let globalMax = allDays.map(\.maximumCelsius).max() ?? day.maximumCelsius
            let span = max(1, globalMax - globalMin)
            let start = max(0, min(1, (day.minimumCelsius - globalMin) / span))
            let end = max(start + 0.08, min(1, (day.maximumCelsius - globalMin) / span))
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.16))
                Capsule()
                    .fill(.tint)
                    .frame(width: max(5, proxy.size.width * (end - start)))
                    .offset(x: proxy.size.width * start)
                    .widgetAccentable()
            }
        }
    }
}

struct EmptyWeatherBoard: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun")
                .font(.system(size: 42))
                .symbolRenderingMode(.hierarchical)
            Text("Meteoblue Weather")
                .font(.headline)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
