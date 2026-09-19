import CoreLocation
import Observation

@MainActor @Observable final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Coordinate, Error>?
    var requesting = false
    var coordinate: Coordinate?
    var attemptedInitialLocation = false
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyKilometer }
    func current() async throws -> Coordinate {
        guard !requesting else { throw APIProblem(code: "location_busy", message: "Still finding your location.") }
        requesting = true
        defer { requesting = false }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                switch manager.authorizationStatus {
                case .notDetermined: manager.requestWhenInUseAuthorization()
                case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
                default: finish(.failure(APIProblem(code: "location_denied", message: "Location access is off. Search for your starting point instead, or allow access in Settings.")))
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.manager.stopUpdatingLocation()
                self.finish(.failure(CancellationError()))
            }
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finish(.failure(APIProblem(code: "location_denied", message: "Search for your starting point, or allow location access in Settings.")))
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        finish(.success(Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)))
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(.failure(error)) }
    private func finish(_ result: Result<Coordinate, Error>) {
        if case .success(let coordinate) = result { self.coordinate = coordinate }
        continuation?.resume(with: result); continuation = nil
    }
}
