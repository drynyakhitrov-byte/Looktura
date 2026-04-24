import Foundation
import CoreLocation
import Observation

/// Singleton wrapper around CLLocationManager that publishes the user's current
/// coordinate via @Observable. Views read `userCoord` (optional) and fall back
/// to a sensible default when permission is denied or a fix hasn't landed yet.
///
/// We deliberately don't request permission from here — `GeoView` owns that
/// flow during onboarding. This class just reacts to whatever authorization
/// state the system is in.
@Observable
final class LocationManager: NSObject {
    static let shared = LocationManager()

    /// Last known user coordinate. `nil` when we don't have a fix yet or the
    /// user denied access.
    var userCoord: CLLocationCoordinate2D? = nil

    /// Current authorization status. Views can choose to hide
    /// distance labels or show a hint when this is `.denied` / `.restricted`.
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Moscow Tverskaya — the demo catalog's centroid. Used when there's no
    /// real fix so the route builder still has a plausible origin.
    let fallbackCoord = CLLocationCoordinate2D(latitude: 55.7600, longitude: 37.6175)
    let fallbackLabel = "Тверская"

    /// Best available start coordinate — real fix if we have one, otherwise the
    /// demo fallback.
    var effectiveStartCoord: CLLocationCoordinate2D {
        userCoord ?? fallbackCoord
    }

    var effectiveStartLabel: String {
        userCoord == nil ? fallbackLabel : "Ты здесь"
    }

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50 // meters — we don't need sub-block precision
        authorizationStatus = manager.authorizationStatus
        startIfAuthorized()
    }

    /// Start producing updates if the user has already granted permission.
    /// Idempotent — safe to call multiple times.
    func startIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    /// Distance in meters between `effectiveStartCoord` and a target coord.
    /// Useful for "distance to store" labels on product cards.
    func distance(toKm coord: CLLocationCoordinate2D) -> Double {
        let a = CLLocation(latitude: effectiveStartCoord.latitude, longitude: effectiveStartCoord.longitude)
        let b = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return a.distance(from: b) / 1000.0
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        authorizationStatus = m.authorizationStatus
        startIfAuthorized()
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        userCoord = last.coordinate
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        // Silent — we already fall back to the demo coord. Surfacing a banner
        // here would be noisy for transient GPS hiccups.
    }
}
