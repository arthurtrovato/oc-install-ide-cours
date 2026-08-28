import MeteoblueCore
import SwiftUI
import WidgetKit

struct WatchWeatherRectangularView: View {
    let model: WeatherDisplayModel

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 178 || proxy.size.height < 74

            ZStack {
                if isFullColor {
                    LinearGradient(
                        colors: atmosphereColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // The iPhone palette stays recognizable, but a small dark veil gives
                    // the tiny Watch typography substantially more contrast on-device.
                    Color.black.opacity(0.11)

                    RoundedRectangle(cornerRadius: compact ? 9 : 10, style: .continuous)
                        .stroke(.white.opacity(0.24), lineWidth: 0.7)
                }

                VStack(spacing: compact ? 1.5 : 2) {
                    topRow(compact: compact)
                    Divider()
                        .foregroundStyle(isFullColor ? .white.opacity(0.48) : .primary.opacity(0.36))
                    hourlyRow(compact: compact)
                }
                .padding(.horizontal, compact ? 3 : 4)
                .padding(.vertical, 2)
                .shadow(
                    color: isFullColor ? .black.opacity(0.24) : .clear,
                    radius: 0.55,
                    x: 0,
                    y: 0.35
                )
            }
            .foregroundStyle(primaryTextColor)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 9 : 10, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
    }

    private func topRow(compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: compact ? 2 : 3) {
            Text(temperature(model.current.temperatureCelsius))
                .font(.system(size: compact ? 16.5 : 18.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .allowsTightening(true)
                .layoutPriority(3)

            Text("↑\(shortTemperature(model.todayMaximumCelsius)) ↓\(shortTemperature(model.todayMinimumCelsius))")
                .font(.system(size: compact ? 9.2 : 10, weight: .bold, design: .rounded))
                .foregroundStyle(secondaryTextColor)
                .monospacedDigit()
                .allowsTightening(true)
                .minimumScaleFactor(0.84)
                .layoutPriority(2)

            Spacer(minLength: 1)

            precipitationSummary(compact: compact)
                .layoutPriority(1)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }

    @ViewBuilder
    private func precipitationSummary(compact: Bool) -> some View {
        let summary = model.todayPrecipitationSummary
        HStack(spacing: 1) {
            Image(systemName: "drop.fill")
                .font(.system(size: compact ? 8 : 9, weight: .bold))
                .foregroundStyle(precipitationColor)
                .widgetAccentable()
            if let amount = summary.totalMillimeters {
                Text(dailyPrecipitation(amount))
                    .foregroundStyle(precipitationColor)
                    .monospacedDigit()
            } else {
                Text("--mm")
                    .foregroundStyle(precipitationColor)
            }
            if let timing = summary.timingAbbreviation,
               let amount = summary.totalMillimeters,
               amount > 0 {
                Text(compactTiming(timing))
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .font(.system(size: compact ? 8.2 : 9, weight: .bold, design: .rounded))
        .allowsTightening(true)
        .minimumScaleFactor(0.74)
    }

    private func hourlyRow(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(model.nextHours.prefix(5).enumerated()), id: \.offset) { _, hour in
                VStack(spacing: compact ? 0.5 : 1) {
                    Text(hourLabel(hour.date))
                        .font(.system(size: compact ? 8.2 : 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .monospacedDigit()

                    Image(systemName: hour.condition.sfSymbolName(isDaylight: hour.isDaylight))
                        .font(.system(size: compact ? 12.6 : 14, weight: .semibold))
                        .symbolRenderingMode(isFullColor ? .multicolor : .hierarchical)
                        .widgetAccentable()
                        .frame(height: compact ? 14.5 : 16.5)

                    Text(temperature(hour.temperatureCelsius))
                        .font(.system(size: compact ? 9.6 : 10.5, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    if let amount = hourlyPrecipitation(hour.precipitationMillimeters) {
                        Text(amount)
                            .font(.system(size: compact ? 6.8 : 7.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(precipitationColor)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    } else {
                        Color.clear.frame(height: compact ? 7.5 : 8.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var isFullColor: Bool {
        widgetRenderingMode == .fullColor
    }

    private var primaryTextColor: Color {
        isFullColor ? .white : .primary
    }

    private var secondaryTextColor: Color {
        isFullColor ? .white.opacity(0.92) : .primary.opacity(0.82)
    }

    private var precipitationColor: Color {
        isFullColor
            ? Color(red: 0.64, green: 0.94, blue: 1.0)
            : .primary
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

    private func compactTiming(_ value: String) -> String {
        value == "tte j." ? "jour" : value
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
