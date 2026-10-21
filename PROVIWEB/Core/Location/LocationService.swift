import Foundation
import CoreLocation
import MapKit
import Combine
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Músico cercano publicado en `UserLocation/{uid}`
public struct NearbyMusician: Identifiable, Hashable {
    public var id: String
    public var coordinate: CLLocationCoordinate2D
    public var name: String
    public var photo: String?
    public var instrument: String?
    public var distanceMeters: Double

    public static func == (lhs: NearbyMusician, rhs: NearbyMusician) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - CoreLocation & Proximity Detection Service
//
// Interoperabilidad con Android:
//   UserLocation/{uid} = { latitude: Double, longitude: Double }  (MainActivity.InitLocation)
// Android lee este nodo completo en LocationActivity.loadUserLocations() y filtra (0,0) en cliente.
// La distancia real NO la filtra Android (muestra a toda persona con ubicación); iOS sí calcula
// distancia con Haversine para el contador "Cercanos" (umbral de 100 m, igual que el de llegada).
public class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published public var userLocation: CLLocationCoordinate2D?
    @Published public var isNearMusiciansAlert: Bool = false
    @Published public var nearbyMusicians: [NearbyMusician] = []
    @Published public var nearbyMusiciansCount: Int = 0
    @Published public var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332), // CDMX default
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private var lastUploadDate: Date = .distantPast
    private var lastUploadLocation: CLLocation?
    private var remoteProfiles: [String: (name: String, photo: String?, instrument: String?)] = [:]
    private var remoteCoordinates: [String: CLLocationCoordinate2D] = [:]
    #if canImport(FirebaseDatabase)
    private var locationObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif
    private var isObservingRemote = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    public func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        observeRemoteLocations()
    }

    // MARK: - Publicación de mi ubicación (UserLocation/{uid})
    /// Escritura compatible con `MainActivity.InitLocation()`: `setValue` con doubles.
    /// Throttle: máximo cada 60 s o si el usuario se movió más de 50 m.
    /// Toda la mutación ocurre en `@MainActor` porque `authenticatedUid` pertenece a un
    /// miembro aislado (y `MainActor.assumeIsolated` no existe en iOS 16).
    private func publishMyLocationIfNeeded(_ location: CLLocation) {
        #if canImport(FirebaseDatabase)
        Task { @MainActor in
            guard let uid = FirebaseService.shared.authenticatedUid else { return }
            let now = Date()
            let movedMeters = self.lastUploadLocation?.distance(from: location) ?? .greatestFiniteMagnitude
            guard now.timeIntervalSince(self.lastUploadDate) > 60 || movedMeters > 50 else { return }
            self.lastUploadDate = now
            self.lastUploadLocation = location
            let values: [String: Any] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ]
            Database.database().reference().child("UserLocation").child(uid).setValue(values)
        }
        #endif
    }

    // MARK: - Observación de músicos (LocationActivity.loadUserLocations)
    private func observeRemoteLocations() {
        #if canImport(FirebaseDatabase)
        guard !isObservingRemote else { return }
        isObservingRemote = true
        let ref = Database.database().reference().child("UserLocation")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                let myUid = FirebaseService.shared.currentUserId
                var coords: [String: CLLocationCoordinate2D] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    let uid = snap.key
                    guard uid != myUid else { continue }
                    let lat = (dict["latitude"] as? NSNumber)?.doubleValue
                    let lng = (dict["longitude"] as? NSNumber)?.doubleValue
                    // Mismo filtro (0,0) que Android.
                    guard let lat = lat, let lng = lng, !(lat == 0 && lng == 0) else { continue }
                    coords[uid] = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                }
                self.remoteCoordinates = coords
                self.fetchMissingProfiles()
                self.rebuildMusicians()
            }
        }
        locationObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
        #endif
    }

    private func fetchMissingProfiles() {
        #if canImport(FirebaseDatabase)
        for uid in remoteCoordinates.keys where remoteProfiles[uid] == nil {
            Database.database().reference().child("Users").child(uid)
                .observeSingleEvent(of: .value) { [weak self] snapshot in
                    Task { @MainActor in
                        guard let self = self, let dict = snapshot.value as? [String: Any] else { return }
                        let name = (dict["username"] as? String)
                            ?? (dict["name"] as? String)
                            ?? "Artista"
                        let photo = (dict["photo"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                            ?? (dict["image"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                        let instrument = (dict["instrument"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                        self.remoteProfiles[uid] = (name: name, photo: photo, instrument: instrument)
                        self.rebuildMusicians()
                    }
                }
        }
        #endif
    }

    private func rebuildMusicians() {
        let center = userLocation.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        var list: [NearbyMusician] = []
        for (uid, coord) in remoteCoordinates {
            let distance = center?.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude)) ?? 0
            let profile = remoteProfiles[uid]
            list.append(NearbyMusician(
                id: uid,
                coordinate: coord,
                name: profile?.name ?? "Artista",
                photo: profile?.photo,
                instrument: profile?.instrument,
                distanceMeters: distance
            ))
        }
        list.sort { $0.distanceMeters < $1.distanceMeters }
        nearbyMusicians = list
        let nearCount = list.filter { $0.distanceMeters <= 100 }.count
        nearbyMusiciansCount = nearCount
        isNearMusiciansAlert = nearCount > 0

        // Centrar el mapa en el músico más cercano si el usuario no ha movido la región a mano.
        if region.center.latitude == 19.4326 && region.center.longitude == -99.1332,
           let first = list.first {
            region.center = first.coordinate
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Los delegados de CoreLocation no garantizan hilo principal: se aplazan las mutaciones
        // de `@Published` a MainActor (SwiftUI observa estos valores) — N3.
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.userLocation = location.coordinate
            self.region.center = location.coordinate
            self.publishMyLocationIfNeeded(location)
            self.rebuildMusicians()
        }
    }
}
