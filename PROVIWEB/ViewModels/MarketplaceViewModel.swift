import Foundation
import SwiftUI
import Combine
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Marketplace Service (RTDB esquema exacto de Android: nodo `Product`)
//
// Réplica de MainFragment.java / PostProductActivity.java (Android):
//   Product/{pId} = { id(vendedor), pId, title, price: String, des, location, cat, type,
//                     photo, photos: [String], currency, acceptsCrypto/Fiat/Balance,
//                     isPromoted, adExpiry, timestamp, averageRating, reviewCount }
@MainActor
public final class MarketplaceService: ObservableObject {
    public static let shared = MarketplaceService()

    @Published public private(set) var products: [ProductModel] = []

    private var rawProducts: [String: [String: Any]] = [:]
    private var sellerNames: [String: String] = [:]
    private var isStarted = false
    #if canImport(FirebaseDatabase)
    private var listObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif

    private init() {}

    public func ensureStarted() {
        guard !isStarted, FirebaseService.shared.canWriteToCloud else { return }
        isStarted = true
        #if canImport(FirebaseDatabase)
        observeProducts()
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func observeProducts() {
        let ref = Database.database().reference().child("Product")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var next: [String: [String: Any]] = [:]
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    next[snap.key] = dict
                }
                self.rawProducts = next
                self.fetchMissingSellers()
                self.rebuild()
            }
        }
        listObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }

    private func fetchMissingSellers() {
        for (_, dict) in rawProducts {
            let sellerId = MarketplaceService.stringValue(dict["id"]) ?? ""
            guard !sellerId.isEmpty, sellerNames[sellerId] == nil else { continue }
            let uid = sellerId
            Database.database().reference().child("Users").child(uid).child("name")
                .observeSingleEvent(of: .value) { [weak self] snapshot in
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.sellerNames[uid] = MarketplaceService.stringValue(snapshot.value) ?? "Vendedor"
                        self.rebuild()
                    }
                }
        }
    }
    #endif

    private func rebuild() {
        let now = Date().timeIntervalSince1970 * 1000
        let names = sellerNames
        let mapped: [ProductModel] = rawProducts.compactMap { key, dict in
            let promoted = MarketplaceService.coerceBool(dict["isPromoted"])
            let expiry = (dict["adExpiry"] as? NSNumber)?.doubleValue ?? 0
            var product = MarketplaceService.parseProduct(key: key, dict: dict, promoted: promoted && expiry > now)
            if let sellerId = product?.sellerId, let name = names[sellerId] {
                product?.sellerName = name
            } else if product != nil {
                product?.sellerName = "Vendedor"
            }
            return product
        }
        // Promocionados primero (MainFragment.java los ordena con `isPromoted && adExpiry > now`).
        products = mapped.sorted { lhs, rhs in
            if lhs.isPromoted != rhs.isPromoted { return lhs.isPromoted }
            return (Int(lhs.timestamp ?? "0") ?? 0) > (Int(rhs.timestamp ?? "0") ?? 0)
        }
    }

    static func parseProduct(key: String, dict: [String: Any], promoted: Bool) -> ProductModel? {
        let title = stringValue(dict["title"]) ?? ""
        guard !title.isEmpty else { return nil }
        // Android guarda `price` como String; se tolera número.
        let price: Double
        if let text = stringValue(dict["price"]), let parsed = Double(text) {
            price = parsed
        } else {
            price = (dict["price"] as? NSNumber)?.doubleValue ?? 0
        }
        var images: [String] = []
        if let photo = stringValue(dict["photo"]), !photo.isEmpty { images.append(photo) }
        if let photos = dict["photos"] as? [String] { images.append(contentsOf: photos.filter { !$0.isEmpty }) }
        let sellerId = stringValue(dict["id"]) ?? ""
        return ProductModel(
            id: key,
            title: title,
            description: stringValue(dict["des"]) ?? "",
            price: price,
            category: stringValue(dict["cat"]) ?? "Otros",
            sellerId: sellerId,
            sellerName: "Cargando...",
            images: images,
            location: stringValue(dict["location"]) ?? "",
            condition: stringValue(dict["type"]) ?? "Nuevo",
            currency: stringValue(dict["currency"]) ?? "USD",
            isPromoted: promoted,
            timestamp: stringValue(dict["timestamp"]) ?? "0"
        )
    }

    static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String { return value }
        if let value = raw as? NSNumber { return value.stringValue }
        return nil
    }

    static func coerceBool(_ raw: Any?) -> Bool {
        if let value = raw as? Bool { return value }
        if let value = raw as? String { return value == "true" || value == "1" }
        if let value = raw as? NSNumber { return value.boolValue }
        return false
    }

    /// Publica un producto con el esquema exacto de PostProductActivity.java (pId = timestamp).
    public func postProduct(title: String, price: String, description: String, category: String, condition: String, location: String, photoURL: String?) {
        #if canImport(FirebaseDatabase)
        guard let uid = FirebaseService.shared.authenticatedUid else { return }
        let millis = "\(Int(Date().timeIntervalSince1970 * 1000))"
        var dict: [String: Any] = [
            "id": uid,
            "pId": millis,
            "title": title,
            "price": price,
            "des": description,
            "location": location,
            "cat": category,
            "type": condition,
            "currency": "USD",
            "acceptsCrypto": false,
            "acceptsFiat": true,
            "acceptsBalance": true,
            "shippingStatus": "Pending",
            "timestamp": millis,
            "isPromoted": false,
            "reviewCount": 0
        ]
        if let photoURL = photoURL, !photoURL.isEmpty {
            dict["photo"] = photoURL
            dict["photos"] = [photoURL]
        }
        Database.database().reference().child("Product").child(millis).setValue(dict)
        #endif
    }
}

// MARK: - Marketplace & Quotes ViewModel
@MainActor
public class MarketplaceViewModel: ObservableObject {
    @Published public var products: [ProductModel] = []
    @Published public var quotes: [QuoteModel] = []
    @Published public var selectedCategory: String = "Todos"
    @Published public var isCreateQuoteSheetPresented: Bool = false
    @Published public var isPostProductPresented: Bool = false
    
    public let categories = ["Todos", "Instrumentos", "Accesorios", "Partituras", "Clases Particulares", "Agrupaciones"]
    
    private let service = MarketplaceService.shared
    private var cancellables: Set<AnyCancellable> = []
    /// `true` cuando la lista proviene del nodo `Product` en la nube (sesión real).
    public let usesLiveMarket: Bool

    public init() {
        // Sesión real → productos del nodo `Product`; modo demo → seed local.
        usesLiveMarket = FirebaseService.shared.canWriteToCloud
        if usesLiveMarket {
            service.ensureStarted()
            service.$products
                .sink { [weak self] list in self?.products = list }
                .store(in: &cancellables)
        } else {
            loadMockProducts()
        }
    }

    public var filteredProducts: [ProductModel] {
        guard selectedCategory != "Todos" else { return products }
        return products.filter { $0.category == selectedCategory }
    }
    
    private func loadMockProducts() {
        products = [
            ProductModel(
                id: "prod_1",
                title: "Violín Profesional Maestro Cremona 4/4",
                description: "Violín de madera de arce europeo con excelente resonancia y proyección. Incluye estuche térmico y arco de pernambuco.",
                price: 1250.00,
                category: "Instrumentos",
                sellerName: "Luthier Garza",
                images: ["https://images.unsplash.com/photo-1612225330812-01a9c6b355ec?w=800&auto=format&fit=crop&q=60"],
                location: "CDMX",
                condition: "Nuevo"
            ),
            ProductModel(
                id: "prod_2",
                title: "Arco de Fibra de Carbono para Violín 4/4",
                description: "Gran balance y durabilidad, ideal para estudiantes avanzados y profesionales.",
                price: 180.00,
                category: "Accesorios",
                sellerName: "Israel Violín",
                images: ["https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800&auto=format&fit=crop&q=60"],
                location: "Puebla",
                condition: "Como Nuevo"
            )
        ]
        
        quotes = [
            QuoteModel(
                id: "quote_1",
                customerId: "user_demo_violin_001",
                customerName: "Israel Violín",
                bandType: "Mariachi Sinfónico",
                eventDate: "15 de Octubre, 2026",
                hours: 3,
                location: "Coyoacán, CDMX",
                budgetProposed: 650.00,
                status: "approved"
            )
        ]
    }
}

// MARK: - Wallet & Web3 ViewModel
@MainActor
public class WalletViewModel: ObservableObject {
    @Published public var walletBalance: WalletBalanceModel = WalletBalanceModel()
    @Published public var isQRScannerPresented: Bool = false
    @Published public var isWithdrawSheetPresented: Bool = false
    @Published public var qrCodeImage: UIImage? = nil
    @Published public var withdrawAmountText: String = ""
    
    private let firebaseService = FirebaseService.shared
    private let web3Service = Web3WalletService.shared
    
    public init() {
        firebaseService.$walletBalance
            .assign(to: &$walletBalance)
        generateWalletQR()
    }
    
    public func generateWalletQR() {
        let address = web3Service.walletAddress
        qrCodeImage = web3Service.generateQRCode(from: "proviweb://connect?address=\(address)")
    }
}
