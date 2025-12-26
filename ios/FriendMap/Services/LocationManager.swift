import Foundation
import CoreLocation
import MapKit

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var mapUpdateTrigger = 0
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: MockData.copenhagenCenter.latitude,
            longitude: MockData.copenhagenCenter.longitude
        ), // Default fallback
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1) // Zoomed out by default for fallback
    )
    @Published var permissionStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Don't auto-request on init, let the view drive it
    }
    
    func checkAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            Logger.error("Location access denied/restricted")
            // Ensure we fallback to Copenhagen or default
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        @unknown default:
            break
        }
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func centerMapOnUser() {
        // First try our cached userLocation
        if let location = userLocation {
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            mapUpdateTrigger += 1
            return
        }
        
        // Fallback: try to get location directly from CLLocationManager
        if let location = locationManager.location?.coordinate {
            userLocation = location
            region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            mapUpdateTrigger += 1
            return
        }
        
        // If still no location, request and start updates
        locationManager.requestLocation()
        locationManager.startUpdatingLocation()
    }
    
    func setRegion(center: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        mapUpdateTrigger += 1
    }
    
    // MARK: - Delegate Methods
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        permissionStatus = manager.authorizationStatus
        if permissionStatus == .authorizedWhenInUse || permissionStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        
        DispatchQueue.main.async {
            self.userLocation = latestLocation.coordinate
            
            // Auto-center map on first significant update if we haven't already
            // This logic can be refined in the View layer if preferred
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger.error("Location Manager Error: \(error.localizedDescription)")
    }
}
