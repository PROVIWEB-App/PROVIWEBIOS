import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Nearby Musician Pin Model (matching Android search.LocationActivity)
public struct NearbyMusicianPin: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let directorName: String
    public let category: String
    public let coordinate: CLLocationCoordinate2D
    public var distanceKm: Double
    public let rating: Double
    public let reviewsCount: Int
    public let pricePerHourUSD: Double
    public let avatarUrl: String
    public let isVerified: Bool
    public let isAvailableNow: Bool
    public let phone: String
    public let instrument: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        directorName: String = "",
        category: String,
        coordinate: CLLocationCoordinate2D,
        distanceKm: Double = 1.2,
        rating: Double = 4.9,
        reviewsCount: Int = 48,
        pricePerHourUSD: Double = 250.0,
        avatarUrl: String = "",
        isVerified: Bool = true,
        isAvailableNow: Bool = true,
        phone: String = "+52 55 1234 5678",
        instrument: String = "Violín"
    ) {
        self.id = id
        self.name = name
        self.directorName = directorName
        self.category = category
        self.coordinate = coordinate
        self.distanceKm = distanceKm
        self.rating = rating
        self.reviewsCount = reviewsCount
        self.pricePerHourUSD = pricePerHourUSD
        self.avatarUrl = avatarUrl
        self.isVerified = isVerified
        self.isAvailableNow = isAvailableNow
        self.phone = phone
        self.instrument = instrument
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: NearbyMusicianPin, rhs: NearbyMusicianPin) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CoreLocation & Proximity Detection Service
public class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published public var userLocation: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332) // Default CDMX
    @Published public var isNearMusiciansAlert: Bool = false
    @Published public var nearbyMusiciansCount: Int = 5
    @Published public var radarRadiusKm: Double = 15.0
    @Published public var selectedMusicianPin: NearbyMusicianPin? = nil
    @Published public var isRadarScanning: Bool = true
    
    @Published public var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332), // CDMX Bellas Artes
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    
    @Published public var allMusicians: [NearbyMusicianPin] = [
        NearbyMusicianPin(
            id: "musician_01",
            name: "Mariachi Real de México",
            directorName: "Mtro. Alejandro Morales",
            category: "Mariachi",
            coordinate: CLLocationCoordinate2D(latitude: 19.4360, longitude: -99.1380),
            distanceKm: 0.8,
            rating: 5.0,
            reviewsCount: 86,
            pricePerHourUSD: 300.0,
            avatarUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400",
            isVerified: true,
            isAvailableNow: true,
            instrument: "Ensamble Mariachi"
        ),
        NearbyMusicianPin(
            id: "musician_02",
            name: "Elena Vargas - Violín Clásico",
            directorName: "Elena Vargas",
            category: "Violinista Solista",
            coordinate: CLLocationCoordinate2D(latitude: 19.4280, longitude: -99.1410),
            distanceKm: 1.4,
            rating: 4.9,
            reviewsCount: 52,
            pricePerHourUSD: 140.0,
            avatarUrl: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400",
            isVerified: true,
            isAvailableNow: true,
            instrument: "Violín Acústico / Eléctrico"
        ),
        NearbyMusicianPin(
            id: "musician_03",
            name: "Cuarteto Bellas Artes",
            directorName: "Lic. Manuel Cordero",
            category: "Cuarteto de Cuerdas",
            coordinate: CLLocationCoordinate2D(latitude: 19.4390, longitude: -99.1290),
            distanceKm: 2.1,
            rating: 4.9,
            reviewsCount: 64,
            pricePerHourUSD: 240.0,
            avatarUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=400",
            isVerified: true,
            isAvailableNow: false,
            instrument: "Violines, Viola & Cello"
        ),
        NearbyMusicianPin(
            id: "musician_04",
            name: "Banda Regional La Imperial",
            directorName: "Gonzalo Beltrán",
            category: "Banda Regional",
            coordinate: CLLocationCoordinate2D(latitude: 19.4190, longitude: -99.1550),
            distanceKm: 3.5,
            rating: 4.8,
            reviewsCount: 41,
            pricePerHourUSD: 450.0,
            avatarUrl: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=400",
            isVerified: true,
            isAvailableNow: true,
            instrument: "Viento & Percusión"
        ),
        NearbyMusicianPin(
            id: "musician_05",
            name: "Estudio Clave de Sol CDMX",
            directorName: "Ing. Roberto Solís",
            category: "Estudio de Grabación",
            coordinate: CLLocationCoordinate2D(latitude: 19.4450, longitude: -99.1450),
            distanceKm: 2.8,
            rating: 5.0,
            reviewsCount: 95,
            pricePerHourUSD: 80.0,
            avatarUrl: "https://images.unsplash.com/photo-1598488035139-bdbb2231ce04?w=400",
            isVerified: true,
            isAvailableNow: true,
            instrument: "Microfonía Valvular Neumann"
        )
    ]
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        recalculateDistances()
    }
    
    public func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.userLocation = location.coordinate
        self.region.center = location.coordinate
        recalculateDistances()
    }
    
    public func updateRadarRadius(_ km: Double) {
        self.radarRadiusKm = km
        let latDelta = km / 111.0 * 2.2
        let lonDelta = km / (111.0 * cos(region.center.latitude * .pi / 180.0)) * 2.2
        self.region.span = MKCoordinateSpan(latitudeDelta: max(0.02, latDelta), longitudeDelta: max(0.02, lonDelta))
        recalculateDistances()
    }
    
    public func recalculateDistances() {
        guard let userLoc = userLocation else { return }
        let currentLoc = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        
        for i in 0..<allMusicians.count {
            let pinLoc = CLLocation(latitude: allMusicians[i].coordinate.latitude, longitude: allMusicians[i].coordinate.longitude)
            let distanceMeters = currentLoc.distance(from: pinLoc)
            allMusicians[i].distanceKm = distanceMeters / 1000.0
        }
        
        let inRange = allMusicians.filter { $0.distanceKm <= radarRadiusKm }
        self.nearbyMusiciansCount = inRange.count
        self.isNearMusiciansAlert = inRange.contains { $0.distanceKm <= 0.5 }
    }
    
    public func musicians(forCategory category: String?) -> [NearbyMusicianPin] {
        allMusicians.filter { pin in
            let matchesCategory = category == nil || category == "Todos" || pin.category == category
            let inRadius = pin.distanceKm <= radarRadiusKm
            return matchesCategory && inRadius
        }
    }
}
