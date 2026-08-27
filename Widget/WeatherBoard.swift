import Foundation
import MeteoblueCore
import SwiftUI

struct WeatherBoard: View {
    let model: WeatherDisplayModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: atmosphereColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 6) {
                header
                currentRow
                Divider().foregroundStyle(.white.opacity(0.36))
                hourlyRow
                Divider().foregroundStyle(.white.opacity(0.36))
                dailyRows
            }
            .foregroundStyle(.white)
            .tint(.white)
            .padding(.horizontal, 14)
            .padding(.top, 5)
            .padding(.bottom, 11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.75)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.78))
            Text(model.snapshot.location.locality)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
            Spacer(minLength: 6)
            if model.freshness != .fresh || model.isFallbackForDifferentLocation {
                Label(staleLabel, systemImage: "clock")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
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
                HStack(spacing: 5) {
                    Text("H \(temperature(model.todayMaximumCelsius))  B \(temperature(model.todayMinimumCelsius))")
                        .monospacedDigit()
                    if let precipitation = compactDailyPrecipitation(model.todayPrecipitationSummary) {
                        Text(precipitation)
                            .foregroundStyle(.cyan.opacity(0.96))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .minimumScaleFactor(0.72)
            }
        }
    }

    private var hourlyRow: some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(Array(model.nextHours.prefix(6).enumerated()), id: \.offset) { _, hour in
                VStack(spacing: 3) {
                    Text(hourLabel(hour.date))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                    Image(systemName: hour.condition.sfSymbolName(isDaylight: hour.isDaylight))
                        .font(.system(size: 16))
                        .symbolRenderingMode(.multicolor)
                        .frame(height: 19)
                    Text(temperature(hour.temperatureCelsius))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    if let probability = hour.precipitationProbabilityPercent, probability >= 10 {
                        Text("\(Int(probability.rounded()))%")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                            .monospacedDigit()
                    } else {
                        Color.clear.frame(height: 8)
                    }
                    if let precipitation = precipitationText(hour.precipitationMillimeters) {
                        Text(precipitation)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.cyan.opacity(0.96))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    } else {
                        Color.clear.frame(height: 8)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 73)
            }
        }
    }

    private var dailyRows: some View {
        VStack(spacing: 3) {
            ForEach(Array(model.nextDays.prefix(5).enumerated()), id: \.offset) { index, day in
                DailyForecastRow(
                    day: day,
                    allDays: Array(model.nextDays.prefix(5)),
                    isToday: index == 0,
                    precipitationSummary: model.precipitationSummary(for: day.date)
                )
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

    private func precipitationText(_ value: Double?) -> String? {
        guard let value, value.isFinite, value > 0 else { return nil }
        let format = value >= 10 ? "%.0f mm" : "%.1f mm"
        return String(format: format, locale: Locale(identifier: "fr_FR"), value)
    }

    private func compactDailyPrecipitation(_ summary: DailyPrecipitationSummary) -> String? {
        guard let value = summary.totalMillimeters, value.isFinite, value > 0 else { return nil }
        let format = value >= 10 ? "%.0fmm" : "%.1fmm"
        let amount = String(format: format, locale: Locale(identifier: "fr_FR"), value)
        if let timing = summary.timingAbbreviation {
            return "\(amount)·\(timing)"
        }
        return amount
    }

    private var atmosphereColors: [Color] {
        switch model.current.condition {
        case .clear, .mostlyClear:
            return model.current.isDaylight
                ? [Color(red: 0.12, green: 0.54, blue: 0.92), Color(red: 0.40, green: 0.76, blue: 0.98)]
                : [Color(red: 0.10, green: 0.16, blue: 0.39), Color(red: 0.31, green: 0.22, blue: 0.58)]
        case .partlyCloudy:
            return [Color(red: 0.16, green: 0.45, blue: 0.80), Color(red: 0.35, green: 0.34, blue: 0.70)]
        case .rain, .showers:
            return [Color(red: 0.10, green: 0.35, blue: 0.66), Color(red: 0.22, green: 0.21, blue: 0.55)]
        case .thunderstorm:
            return [Color(red: 0.16, green: 0.17, blue: 0.39), Color(red: 0.36, green: 0.18, blue: 0.49)]
        case .snow, .snowShowers, .sleet:
            return [Color(red: 0.25, green: 0.67, blue: 0.85), Color(red: 0.24, green: 0.37, blue: 0.72)]
        case .overcast, .fog, .haze, .unknown:
            return [Color(red: 0.32, green: 0.43, blue: 0.56), Color(red: 0.22, green: 0.27, blue: 0.42)]
        }
    }
}

private struct DailyForecastRow: View {
    let day: DailyForecast
    let allDays: [DailyForecast]
    let isToday: Bool
    let precipitationSummary: DailyPrecipitationSummary

    var body: some View {
        HStack(spacing: 4) {
            Text(weekday(day.date))
                .font(.caption.weight(isToday ? .bold : .semibold))
                .frame(width: 34, alignment: .leading)
            Image(systemName: day.condition.sfSymbolName(isDaylight: true))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 14))
                .frame(width: 20)
            precipitationCell
                .frame(width: 46, alignment: .leading)
            Text(temp(day.minimumCelsius))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 31, alignment: .trailing)
            TemperatureRangeBar(day: day, allDays: allDays)
                .frame(height: 7)
            Text(temp(day.maximumCelsius))
                .font(.caption.weight(.semibold).monospacedDigit())
                .frame(width: 31, alignment: .trailing)
        }
        .frame(height: 24)
    }

    @ViewBuilder
    private var precipitationCell: some View {
        if let amount = precipitationAmount(precipitationSummary.totalMillimeters) {
            VStack(alignment: .leading, spacing: -1) {
                Text(amount)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan.opacity(0.96))
                    .monospacedDigit()
                if let timing = precipitationSummary.timingAbbreviation {
                    Text(timing)
                        .font(.system(size: 6.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }
            }
            .lineLimit(1)
        } else {
            Color.clear
        }
    }

    private func precipitationAmount(_ value: Double?) -> String? {
        guard let value, value.isFinite, value > 0 else { return nil }
        let format = value >= 10 ? "%.0fmm" : "%.1fmm"
        return String(format: format, locale: Locale(identifier: "fr_FR"), value)
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
                Capsule().fill(.white.opacity(0.22))
                Capsule()
                    .fill(.white.opacity(0.88))
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
