import Foundation

// MARK: - AI Professor Models
public struct AIProfessorSessionModel: Identifiable, Codable, Hashable {
    public var id: String
    public var userId: String
    public var date: Date
    public var instrument: String
    public var exerciseName: String
    public var totalDuration: TimeInterval
    public var overallScore: Double // 0 - 100
    public var pitchAccuracy: Double // 0 - 100
    public var postureScore: Double // 0 - 100
    public var rhythmConsistency: Double // 0 - 100
    public var detectedNotesCount: Int
    public var maestroFeedback: String
    public var recommendedFocus: [String]
    
    public init(
        id: String = UUID().uuidString,
        userId: String = "",
        date: Date = Date(),
        instrument: String = "Violín",
        exerciseName: String = "Escala de Re Mayor (Suzuki Vol. 1)",
        totalDuration: TimeInterval = 0,
        overallScore: Double = 0,
        pitchAccuracy: Double = 0,
        postureScore: Double = 0,
        rhythmConsistency: Double = 0,
        detectedNotesCount: Int = 0,
        maestroFeedback: String = "Excelente control del arco y colocación de la muñeca izquierda.",
        recommendedFocus: [String] = ["Mantener el codo derecho a la altura de la cuerda", "Afinar el Fa sostenido con el segundo dedo"]
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.instrument = instrument
        self.exerciseName = exerciseName
        self.totalDuration = totalDuration
        self.overallScore = overallScore
        self.pitchAccuracy = pitchAccuracy
        self.postureScore = postureScore
        self.rhythmConsistency = rhythmConsistency
        self.detectedNotesCount = detectedNotesCount
        self.maestroFeedback = maestroFeedback
        self.recommendedFocus = recommendedFocus
    }
}

// MARK: - Live Practice & Podcast Sessions
public struct LiveSessionModel: Identifiable, Codable, Hashable {
    public var id: String
    public var hostId: String
    public var hostName: String
    public var hostDp: String?
    public var title: String
    public var mode: LiveMode // .practice or .podcast
    public var listenersCount: Int
    public var isLive: Bool
    public var channelName: String
    
    public init(
        id: String = UUID().uuidString,
        hostId: String = "",
        hostName: String = "",
        hostDp: String? = nil,
        title: String = "Sesión de Práctica en Vivo",
        mode: LiveMode = .practice,
        listenersCount: Int = 1,
        isLive: Bool = true,
        channelName: String = ""
    ) {
        self.id = id
        self.hostId = hostId
        self.hostName = hostName
        self.hostDp = hostDp
        self.title = title
        self.mode = mode
        self.listenersCount = listenersCount
        self.isLive = isLive
        self.channelName = channelName.isEmpty ? "room_\(id)" : channelName
    }
}

public enum LiveMode: String, Codable {
    case practice
    case podcast
    case masterclass
}

// MARK: - Marketplace Product
public struct ProductModel: Identifiable, Codable, Hashable {
    public var id: String
    public var title: String
    public var description: String
    public var price: Double
    public var category: String
    public var sellerId: String
    public var sellerName: String
    public var images: [String]
    public var location: String
    public var latitude: Double?
    public var longitude: Double?
    public var condition: String // "Nuevo", "Como Nuevo", "Usado"
    
    public init(
        id: String = UUID().uuidString,
        title: String = "",
        description: String = "",
        price: Double = 0.0,
        category: String = "Instrumentos",
        sellerId: String = "",
        sellerName: String = "",
        images: [String] = [],
        location: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        condition: String = "Nuevo"
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.category = category
        self.sellerId = sellerId
        self.sellerName = sellerName
        self.images = images
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.condition = condition
    }
}

// MARK: - Musical Band Quotes (Cotizaciones)
public struct QuoteModel: Identifiable, Codable, Hashable {
    public var id: String
    public var customerId: String
    public var customerName: String
    public var bandType: String // "Mariachi", "Banda", "Cuarteto de Cuerdas", "Violinista Solista"
    public var eventDate: String
    public var hours: Int
    public var location: String
    public var budgetProposed: Double
    public var status: String // "pending", "approved", "rejected", "completed"
    public var notes: String?
    
    public init(
        id: String = UUID().uuidString,
        customerId: String = "",
        customerName: String = "",
        bandType: String = "Mariachi",
        eventDate: String = "",
        hours: Int = 2,
        location: String = "",
        budgetProposed: Double = 0.0,
        status: String = "pending",
        notes: String? = nil
    ) {
        self.id = id
        self.customerId = customerId
        self.customerName = customerName
        self.bandType = bandType
        self.eventDate = eventDate
        self.hours = hours
        self.location = location
        self.budgetProposed = budgetProposed
        self.status = status
        self.notes = notes
    }
}

// MARK: - QAV Wallet & Balance
public struct WalletBalanceModel: Codable, Hashable {
    public var balanceUSD: Double
    public var diamonds: Int
    public var referralCount: Int
    public var walletAddress: String?
    public var privateKeyHash: String?
    
    public init(
        balanceUSD: Double = 0.0,
        diamonds: Int = 0,
        referralCount: Int = 0,
        walletAddress: String? = nil,
        privateKeyHash: String? = nil
    ) {
        self.balanceUSD = balanceUSD
        self.diamonds = diamonds
        self.referralCount = referralCount
        self.walletAddress = walletAddress
        self.privateKeyHash = privateKeyHash
    }
}
