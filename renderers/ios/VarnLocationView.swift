import CoreLocation
import UIKit

/// Where the device is, for as long as the node asking for it is on screen.
///
/// The permission is asked for when the first one is mounted and the answer arrives later, so the fix
/// is started from the authorization callback rather than from the ask. A reader who says no is told
/// through the error, since a screen that waits silently for a fix that will never come reads as broken.
final class VarnLocationView: UIView, CLLocationManagerDelegate, VarnSettling {
    private let manager = CLLocationManager()

    private var watching = false
    private var accuracy = "fine"
    private var asked: String?

    var onChange: (([String: Any]) -> Void)?
    var onError: (([String: Any]) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        isHidden = true
        manager.delegate = self
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    deinit {
        manager.stopUpdatingLocation()
    }

    func setWatch(_ value: Bool) {
        watching = value
    }

    func setAccuracy(_ value: String?) {
        accuracy = value ?? "fine"
    }

    func settle() {
        let wanted = "\(watching)/\(accuracy)"

        guard wanted != asked else {
            return
        }

        asked = wanted
        ask()
    }

    private func ask() {
        manager.stopUpdatingLocation()
        manager.desiredAccuracy = accuracy == "fine" ? kCLLocationAccuracyBest : kCLLocationAccuracyHundredMeters

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            return
        }

        start()
    }

    private func start() {
        let allowed: [CLAuthorizationStatus] = [.authorizedWhenInUse, .authorizedAlways]

        guard allowed.contains(manager.authorizationStatus) else {
            onError?(["message": "this device is not allowed to say where it is"])
            return
        }

        if watching {
            manager.startUpdatingLocation()
            return
        }

        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else {
            return
        }

        start()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last else {
            return
        }

        onChange?([
            "latitude": fix.coordinate.latitude,
            "longitude": fix.coordinate.longitude,
            "accuracy": max(0, fix.horizontalAccuracy),
        ])
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError problem: Error) {
        onError?(["message": problem.localizedDescription])
    }
}
