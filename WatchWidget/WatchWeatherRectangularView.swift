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

                    // Keep the iPhone-like weather palette while prioritizing legibility
                    // at the tiny accessory-rectangular scale used on a physical Watch.
                    Color.black.opacity(0.16)

                    RoundedRectangle(cornerRadius: compact ? 9 : 10, style: .continuous)
                        .stroke(.white.opacity(0.26), lineWidth: 0.7)
                }

                VStack(spacing: compact ? 1.25 : 1.75) {
                    topRow(compact: compact)
                    Divider()
                        .foregroundStyle(isFullColor ? .white.opacity(0.48) : .primary.opacity(0.36))
                    hourlyRow(compact: compact)
                }
                .padding(.horizontal, compact ? 3 : 4)
                .padding(.vertical, 1.5)
                .shadow(
                    color: isFullColor ? .black.opacity(0.28) : .clear,
                    radius: 0.6,
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
                .font(.system(size: compact ? 17 : 19, weight: .bold, design: .rounded))
                .monospacedDigit()
                .allowsTightening(true)
                .layoutPriority(3)

            Text("↑\(shortTemperature(model.todayMaximumCelsius)) ↓\(shortTemperature(model.todayMinimumCelsius))")
                .font(.system(size: compact ? 9.5 : 10.3, weight: .bold, design: .rounded))
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
        HStack(spacing: 1.5) {
            Image(systemName: "drop.fill")
                .font(.system(size: compact ? 8.3 : 9.2, weight: .bold))
                .foregroundStyle(precipitationColor)
                .widgetAccentable()

            if let amount = summary.totalMillimeters {
                Text(dailyPrecipitation(amount))
                    .foregroundStyle(precipitationColor)
                    .monospacedDigit()
            } else {
                Text("-- mm")
                    .foregroundStyle(precipitationColor)
            }

            if let timing = visibleTiming(summary.timingAbbreviation),
               let amount = summary.totalMillimeters,
               amount > 0 {
                Text("· \(timing)")
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .font(.system(size: compact ? 8.4 : 9.2, weight: .bold, design: .rounded))
        .allowsTightening(true)
        .minimumScaleFactor(0.76)
    }

    private func hourlyRow(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(model.nextHours.prefix(5).enumerated()), id: \.offset) { _, hour in
                VStack(spacing: compact ? 0.35 : 0.75) {
                    Text(hourLabel(hour.date))
                        .font(.system(size: compact ? 9 : 9.8, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .monospacedDigit()

                    Image(systemName: hour.condition.sfSymbolName(isDaylight: hour.isDaylight))
                        .font(.system(size: compact ? 13.4 : 14.8, weight: .semibold))
                        .symbolRenderingMode(isFullColor ? .multicolor : .hierarchical)
                        .widgetAccentable()
                        .frame(height: compact ? 15 : 17)

                    Text(temperature(hour.temperatureCelsius))
                        .font(.system(size: compact ? 10.2 : 11, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    if let amount = hourlyPrecipitation(hour.precipitationMillimeters) {
                        Text(amount)
                            .font(.system(size: compact ? 7 : 7.7, weight: .semibold, design: .rounded))
                            .foregroundStyle(precipitationColor)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    } else {
                        Color.clear.frame(height: compact ? 7.5 : 8.5)
                    }
                }
                .frame(maxWidth: .infinity)
                .minimumScaleFactor(0.82)
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
        isFullColor ? .white.opacity(0.96) : .primary.opacity(0.86)
    }

    private var precipitationColor: Color {
        isFullColor
            ? Color(red: 0.68, green: 0.96, blue: 1.0)
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

    private func visibleTiming(_ value: String?) -> String? {
        guard let value else { return nil }
        // The precipitation value is already a daily total, so "all day" is redundant
        // in this constrained slot. Keep only timings that add information.
        if value == "tte j." || value == "jour" { return nil }
        return value
    }

    private func hourLabel(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: model.snapshot.location.timeZoneIdentifier) ?? .current
        let hour = calendar.component(.hour, from: date)
        return String(format: "%02d", hour)
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
        guard value.isFinite else { return "-- mm" }
        let format = value >= 10 ? "%.0f mm" : "%.1f mm"
        return String(format: format, locale: Locale(identifier: "fr_FR"), max(0, value))
    }

    private func hourlyPrecipitation(_ value: Double?) -> String? {
        guard let value, value.isFinite, value >= 0.05 else { return nil }
        let format = value >= 10 ? "%.0f" : "%.1f"
        return String(format: format, locale: Locale(identifier: "fr_FR"), value)
    }
}
