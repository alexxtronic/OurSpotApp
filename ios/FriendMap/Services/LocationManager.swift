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
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var permissionStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func centerMapOnUser() {
        guard let location = userLocation else { return }
        region = MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapUpdateTrigger += 1
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
            // Only auto-center once on first load if needed, defaulting to Copenhagen otherwise
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager Error: \(error.localizedDescription)")
    }
}
