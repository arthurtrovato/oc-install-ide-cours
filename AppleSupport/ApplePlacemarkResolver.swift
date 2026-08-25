import CoreLocation
import Foundation
import MeteoblueCore

struct ApplePlacemarkResolver {
    static func weatherLocation(from location: CLLocation) async -> WeatherLocation {
        let coordinate = GeoCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        let locality = placemark?.locality
            ?? placemark?.subLocality
            ?? placemark?.subAdministrativeArea
            ?? String(format: "%.3f, %.3f", coordinate.latitude, coordinate.longitude)
        let zone = placemark?.timeZone?.identifier ?? TimeZone.current.identifier
        let elevation = location.verticalAccuracy >= 0 ? location.altitude : nil
        return WeatherLocation(
            coordinate: coordinate,
            locality: locality,
            countryCode: placemark?.isoCountryCode,
            timeZoneIdentifier: zone,
            elevationMeters: elevation
        )
    }
}
