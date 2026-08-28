import CoreLocation
import Foundation

extension CLAuthorizationStatus {
    var diagnosticValue: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }

    var allowsForegroundLocation: Bool {
        self == .authorizedAlways || self == .authorizedWhenInUse
    }
}

@MainActor
final class AppleLocationClient: NSObject, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 5_000
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    var isAuthorizedForWidgetUpdates: Bool {
#if os(watchOS)
        manager.authorizationStatus.allowsForegroundLocation
#else
        manager.isAuthorizedForWidgetUpdates
#endif
    }

    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
            let updated = manager.authorizationStatus
            if updated != .notDetermined {
                finishAuthorization(with: updated)
            }
        }
    }

    func requestCurrentLocation(promptIfNeeded: Bool) async -> CLLocation? {
        if promptIfNeeded && manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            return nil
        }
        guard manager.authorizationStatus.allowsForegroundLocation else { return nil }
        guard continuation == nil else { return nil }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
            timeoutTask?.cancel()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.finish(with: nil) }
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined else { return }
        finishAuthorization(with: status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let best = locations
            .filter { $0.horizontalAccuracy >= 0 }
            .min { $0.horizontalAccuracy < $1.horizontalAccuracy }
            ?? locations.last
        finish(with: best)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }

    private func finishAuthorization(with status: CLAuthorizationStatus) {
        let pending = authorizationContinuation
        authorizationContinuation = nil
        pending?.resume(returning: status)
    }

    private func finish(with location: CLLocation?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let pending = continuation
        continuation = nil
        pending?.resume(returning: location)
    }
}
