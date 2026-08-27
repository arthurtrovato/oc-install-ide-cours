import MeteoblueCore
import SwiftUI
import WidgetKit

struct WatchWeatherRectangularView: View {
    let model: WeatherDisplayModel

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 178 || proxy.size.height < 74
            VStack(spacing: compact ? 1 : 2) {
                topRow(compact: compact)
                Divider().opacity(0.28)
                hourlyRow(compact: compact)
            }
            .padding(.horizontal, compact ? 2 : 3)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    private func topRow(compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: compact ? 2 : 3) {
            Text(temperature(model.current.temperatureCelsius))
                .font(.system(size: compact ? 14 : 16, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text("↑\(shortTemperature(model.todayMaximumCelsius)) ↓\(shortTemperature(model.todayMinimumCelsius))")
                .font(.system(size: compact ? 7.5 : 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer(minLength: 1)

            precipitationSummary(compact: compact)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    @ViewBuilder
    private func precipitationSummary(compact: Bool) -> some View {
        let summary = model.todayPrecipitationSummary
        HStack(spacing: 1) {
            Image(systemName: "drop.fill")
                .font(.system(size: compact ? 6.5 : 7.5, weight: .semibold))
                .widgetAccentable()
            if let amount = summary.totalMillimeters {
                Text(dailyPrecipitation(amount))
                    .monospacedDigit()
            } else {
                Text("--mm")
            }
            if let timing = summary.timingAbbreviation,
               let amount = summary.totalMillimeters,
               amount > 0 {
                Text(timing)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: compact ? 6.5 : 7.5, weight: .semibold, design: .rounded))
        .minimumScaleFactor(0.68)
    }

    private func hourlyRow(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(model.nextHours.prefix(5).enumerated()), id: \.offset) { _, hour in
                VStack(spacing: 0) {
                    Text(hourLabel(hour.date))
                        .font(.system(size: compact ? 6.5 : 7.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Image(systemName: hour.condition.sfSymbolName(isDaylight: hour.isDaylight))
                        .font(.system(size: compact ? 10.5 : 12, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .widgetAccentable()
                        .frame(height: compact ? 13 : 15)

                    Text(temperature(hour.temperatureCelsius))
                        .font(.system(size: compact ? 7.5 : 8.5, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    if let amount = hourlyPrecipitation(hour.precipitationMillimeters) {
                        Text(amount)
                            .font(.system(size: compact ? 5.5 : 6.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Color.clear.frame(height: compact ? 6 : 7)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func hourLabel(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: model.snapshot.location.timeZoneIdentifier) ?? .current
        return "\(calendar.component(.hour, from: date))h"
    }

    private func temperature(_ value: Double?) -> String {
        guard let value else { return "--°" }
        return "\(Int(value.rounded()))°"
    }

    private func shortTemperature(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))°"
    }

    private func dailyPrecipitation(_ value: Double) -> String {
        guard value.isFinite else { return "--mm" }
        let format = value >= 10 ? "%.0fmm" : "%.1fmm"
        return String(format: format, locale: Locale(identifier: "fr_FR"), max(0, value))
    }

    private func hourlyPrecipitation(_ value: Double?) -> String? {
        guard let value, value.isFinite, value >= 0.05 else { return nil }
        let format = value >= 10 ? "%.0fmm" : "%.1fmm"
        return String(format: format, locale: Locale(identifier: "fr_FR"), value)
    }
}
