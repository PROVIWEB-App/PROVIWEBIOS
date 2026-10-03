import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - CoreLocation & Proximity Detection Service
public class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published public var userLocation: CLLocationCoordinate2D?
    @Published public var isNearMusiciansAlert: Bool = false
    @Published public var nearbyMusiciansCount: Int = 0
    @Published public var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332), // CDMX default
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    public func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.userLocation = location.coordinate
        self.region.center = location.coordinate
        
        checkNearbyMusicians(currentLocation: location)
    }
    
    private func checkNearbyMusicians(currentLocation: CLLocation) {
        // Mock nearby musicians coordinates
        let nearbyCoords = [
            CLLocation(latitude: currentLocation.coordinate.latitude + 0.0005, longitude: currentLocation.coordinate.longitude + 0.0004), // ~70m away
            CLLocation(latitude: currentLocation.coordinate.latitude - 0.0007, longitude: currentLocation.coordinate.longitude + 0.0006)  // ~95m away
        ]
        
        var count = 0
        for spot in nearbyCoords {
            let distanceMeters = currentLocation.distance(from: spot)
            if distanceMeters <= 100.0 { // 100 meters threshold matching Android logic
                count += 1
            }
        }
        
        if count > 0 {
            self.nearbyMusiciansCount = count
            self.isNearMusiciansAlert = true
        }
    }
}
