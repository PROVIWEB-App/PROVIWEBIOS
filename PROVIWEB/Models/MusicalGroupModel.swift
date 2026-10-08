import Foundation

// MARK: - Musical Groups, Mariachis & Hiring Quotation Models
public struct MusicalGroupProfileModel: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var directorName: String
    public var directorId: String
    public var groupType: GroupType
    public var location: String
    public var coverageRadiusKm: Int
    public var membersCount: Int
    public var avatarUrl: String?
    public var coverBannerUrl: String?
    public var rating: Double
    public var reviewsCount: Int
    public var basePricePerHourUSD: Double
    public var experienceYears: Int
    public var repertoireCount: Int
    public var isVerified: Bool
    public var sampleVideoUrls: [String]
    public var packages: [MusicalServicePackageModel]
    
    public enum GroupType: String, Codable, CaseIterable {
        case mariachi = "Mariachi"
        case cuartetoCuerdas = "Cuarteto de Cuerdas"
        case bandaSinaloense = "Banda Sinaloense"
        case trioRomantico = "Trío Romántico"
        case orquestaCamara = "Orquesta de Cámara"
        case jazzEnsemble = "Ensamble de Jazz"
        case violinSolista = "Violinista Solista"
        case grupoVersatil = "Grupo Versátil"
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        directorName: String,
        directorId: String,
        groupType: GroupType = .mariachi,
        location: String = "Ciudad de México",
        coverageRadiusKm: Int = 50,
        membersCount: Int = 8,
        avatarUrl: String? = nil,
        coverBannerUrl: String? = nil,
        rating: Double = 4.9,
        reviewsCount: Int = 64,
        basePricePerHourUSD: Double = 250.0,
        experienceYears: Int = 12,
        repertoireCount: Int = 300,
        isVerified: Bool = true,
        sampleVideoUrls: [String] = [],
        packages: [MusicalServicePackageModel] = []
    ) {
        self.id = id
        self.name = name
        self.directorName = directorName
        self.directorId = directorId
        self.groupType = groupType
        self.location = location
        self.coverageRadiusKm = coverageRadiusKm
        self.membersCount = membersCount
        self.avatarUrl = avatarUrl
        self.coverBannerUrl = coverBannerUrl
        self.rating = rating
        self.reviewsCount = reviewsCount
        self.basePricePerHourUSD = basePricePerHourUSD
        self.experienceYears = experienceYears
        self.repertoireCount = repertoireCount
        self.isVerified = isVerified
        self.sampleVideoUrls = sampleVideoUrls
        self.packages = packages
    }
}

public struct MusicalServicePackageModel: Identifiable, Codable, Hashable {
    public var id: String
    public var title: String
    public var durationHours: Double
    public var musiciansCount: Int
    public var description: String
    public var priceUSD: Double
    public var includesSoundEquipment: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        durationHours: Double = 1.0,
        musiciansCount: Int = 8,
        description: String = "Serenata tradicional con traje de gala y repertorio completo a elegir.",
        priceUSD: Double = 250.0,
        includesSoundEquipment: Bool = false
    ) {
        self.id = id
        self.title = title
        self.durationHours = durationHours
        self.musiciansCount = musiciansCount
        self.description = description
        self.priceUSD = priceUSD
        self.includesSoundEquipment = includesSoundEquipment
    }
}

public struct MusicalQuoteModel: Identifiable, Codable, Hashable {
    public var id: String
    public var groupId: String
    public var groupName: String
    public var groupAvatar: String?
    public var clientId: String
    public var clientName: String
    public var eventType: String
    public var eventDate: Date
    public var venueAddress: String
    public var durationHours: Double
    public var quotedPriceUSD: Double
    public var status: QuoteStatus
    public var clientNotes: String?
    public var responseNotes: String?
    public var createdAt: Date
    
    public enum QuoteStatus: String, Codable, CaseIterable {
        case pending = "Pendiente"
        case accepted = "Aceptada"
        case declined = "Declinada"
        case paid = "Confirmada & Pagada"
    }
    
    public init(
        id: String = UUID().uuidString,
        groupId: String,
        groupName: String,
        groupAvatar: String? = nil,
        clientId: String,
        clientName: String,
        eventType: String = "Serenata de Cumpleaños",
        eventDate: Date = Date().addingTimeInterval(86400 * 5),
        venueAddress: String = "Polanco, CDMX",
        durationHours: Double = 2.0,
        quotedPriceUSD: Double = 500.0,
        status: QuoteStatus = .pending,
        clientNotes: String? = "Deseamos 2 canciones especiales para la entrada.",
        responseNotes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.groupId = groupId
        self.groupName = groupName
        self.groupAvatar = groupAvatar
        self.clientId = clientId
        self.clientName = clientName
        self.eventType = eventType
        self.eventDate = eventDate
        self.venueAddress = venueAddress
        self.durationHours = durationHours
        self.quotedPriceUSD = quotedPriceUSD
        self.status = status
        self.clientNotes = clientNotes
        self.responseNotes = responseNotes
        self.createdAt = createdAt
    }
}
