import XCTest
@testable import MeteoblueCore

final class WeatherConditionTests: XCTestCase {
    func testAllDailyPictocodesMapDeterministically() {
        let expected: [WeatherCondition] = [
            .clear, .mostlyClear, .partlyCloudy, .overcast, .fog, .rain, .showers,
            .thunderstorm, .snow, .snowShowers, .sleet, .rain, .snow, .rain, .snow, .rain, .snow
        ]
        XCTAssertEqual((1...17).map { MeteoblueConditionMapper.condition(for: $0, set: .daily) }, expected)
    }

    func testAllDetailedHourlyPictocodesMapDeterministically() {
        let expected: [WeatherCondition] = [
            .clear, .clear, .clear, .mostlyClear, .mostlyClear, .mostlyClear,
            .partlyCloudy, .partlyCloudy, .partlyCloudy,
            .partlyCloudy, .partlyCloudy, .partlyCloudy,
            .haze, .haze, .haze, .fog, .fog, .fog,
            .overcast, .overcast, .overcast, .overcast,
            .rain, .snow, .rain, .snow, .rain, .rain, .snow,
            .rain, .showers, .snowShowers, .rain, .snow, .sleet
        ]
        XCTAssertEqual((1...35).map { MeteoblueConditionMapper.condition(for: $0, set: .hourlyDetailed) }, expected)
    }

    func testUnknownAndMissingCodesAreSafe() {
        XCTAssertEqual(MeteoblueConditionMapper.condition(for: nil, set: .daily), .unknown)
        XCTAssertEqual(MeteoblueConditionMapper.condition(for: 999, set: .hourlyDetailed), .unknown)
    }

    func testDayNightSymbolsDifferWhereUseful() {
        XCTAssertEqual(WeatherCondition.clear.sfSymbolName(isDaylight: true), "sun.max.fill")
        XCTAssertEqual(WeatherCondition.clear.sfSymbolName(isDaylight: false), "moon.stars.fill")
        XCTAssertEqual(WeatherCondition.rain.sfSymbolName(isDaylight: true), "cloud.rain.fill")
    }
}
