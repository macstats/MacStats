import CoreLocation

/// Requests Location Services authorization so CoreWLAN can read WiFi SSID.
/// macOS 13+ requires location permission for CWWiFiClient.interface()?.ssid().
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    func requestAuthorization() {
        manager.delegate = self
        // Only request if not yet determined; avoid repeated prompts
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // No action needed — once authorized, CoreWLAN returns SSID automatically
    }
}
