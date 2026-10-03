import Foundation
import SwiftUI
import Combine

// MARK: - Marketplace & Quotes ViewModel
@MainActor
public class MarketplaceViewModel: ObservableObject {
    @Published public var products: [ProductModel] = []
    @Published public var quotes: [QuoteModel] = []
    @Published public var selectedCategory: String = "Todos"
    @Published public var isCreateQuoteSheetPresented: Bool = false
    
    public let categories = ["Todos", "Instrumentos", "Accesorios", "Partituras", "Clases Particulares", "Agrupaciones"]
    
    public init() {
        loadMockProducts()
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
