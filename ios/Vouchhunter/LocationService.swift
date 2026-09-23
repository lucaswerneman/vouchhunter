import CoreLocation
import Foundation

@MainActor
final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  @Published var location: CLLocation?
  @Published var message: String?
  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
  }
  func start() {
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways: manager.startUpdatingLocation()
    default: message = "Tillåt platsåtkomst i Inställningar för att hitta och samla objekt."
    }
  }
  func stop() { manager.stopUpdatingLocation() }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if manager.authorizationStatus != .notDetermined { start() }
  }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let last = locations.last else { return }
    location = last
    message = nil
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    message = "Din position kunde inte hämtas. Försök igen utomhus."
  }
  func payload() throws -> [String: Any] {
    guard let location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 35,
      abs(location.timestamp.timeIntervalSinceNow) < 45
    else {
      throw APIError.message("Väntar på en tillräckligt noggrann position. Försök igen utomhus.")
    }
    return [
      "lat": location.coordinate.latitude, "lon": location.coordinate.longitude,
      "accuracy": location.horizontalAccuracy,
      "captured_at": location.timestamp.timeIntervalSince1970,
    ]
  }
}
