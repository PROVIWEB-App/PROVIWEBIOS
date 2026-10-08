import Foundation

// MARK: - Artistic Events, Tickets & Collaborators Models
public struct ArtisticEventModel: Identifiable, Codable, Hashable {
    public var id: String
    public var title: String
    public var organizerId: String
    public var organizerName: String
    public var organizerDp: String?
    public var description: String
    public var bannerUrl: String?
    public var venueName: String
    public var address: String
    public var latitude: Double?
    public var longitude: Double?
    public var eventDate: Date
    public var durationHours: Double
    public var category: EventCategory
    public var ticketPriceUSD: Double
    public var ticketPriceDiamonds: Int
    public var totalCapacity: Int
    public var ticketsSold: Int
    public var isFree: Bool
    public var isLiveStreamed: Bool
    public var liveStreamUrl: String?
    public var status: EventStatus
    public var schedule: [EventScheduleItem]
    public var collaborators: [EventCollaboratorItem]
    
    public enum EventCategory: String, Codable, CaseIterable {
        case concert = "Concierto"
        case recital = "Recital"
        case masterclass = "Masterclass"
        case serenade = "Serenata"
        case festival = "Festival"
        case conference = "Conferencia"
        case jamSession = "Jam Session"
        
        public var icon: String {
            switch self {
            case .concert: return "music.mic"
            case .recital: return "pianokeys"
            case .masterclass: return "graduationcap.fill"
            case .serenade: return "heart.fill"
            case .festival: return "sparkles"
            case .conference: return "person.3.fill"
            case .jamSession: return "guitars.fill"
            }
        }
    }
    
    public enum EventStatus: String, Codable {
        case upcoming = "Próximo"
        case ongoing = "En Vivo"
        case completed = "Finalizado"
        case soldOut = "Agotado"
        case cancelled = "Cancelado"
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        organizerId: String,
        organizerName: String,
        organizerDp: String? = nil,
        description: String,
        bannerUrl: String? = nil,
        venueName: String,
        address: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        eventDate: Date = Date().addingTimeInterval(86400 * 3),
        durationHours: Double = 2.0,
        category: EventCategory = .concert,
        ticketPriceUSD: Double = 25.0,
        ticketPriceDiamonds: Int = 150,
        totalCapacity: Int = 200,
        ticketsSold: Int = 45,
        isFree: Bool = false,
        isLiveStreamed: Bool = true,
        liveStreamUrl: String? = nil,
        status: EventStatus = .upcoming,
        schedule: [EventScheduleItem] = [],
        collaborators: [EventCollaboratorItem] = []
    ) {
        self.id = id
        self.title = title
        self.organizerId = organizerId
        self.organizerName = organizerName
        self.organizerDp = organizerDp
        self.description = description
        self.bannerUrl = bannerUrl
        self.venueName = venueName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.eventDate = eventDate
        self.durationHours = durationHours
        self.category = category
        self.ticketPriceUSD = ticketPriceUSD
        self.ticketPriceDiamonds = ticketPriceDiamonds
        self.totalCapacity = totalCapacity
        self.ticketsSold = ticketsSold
        self.isFree = isFree
        self.isLiveStreamed = isLiveStreamed
        self.liveStreamUrl = liveStreamUrl
        self.status = status
        self.schedule = schedule
        self.collaborators = collaborators
    }
}

public struct EventScheduleItem: Identifiable, Codable, Hashable {
    public var id: String
    public var timeString: String
    public var activityTitle: String
    public var artistName: String?
    
    public init(
        id: String = UUID().uuidString,
        timeString: String,
        activityTitle: String,
        artistName: String? = nil
    ) {
        self.id = id
        self.timeString = timeString
        self.activityTitle = activityTitle
        self.artistName = artistName
    }
}

public struct EventCollaboratorItem: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var role: String
    public var avatarUrl: String?
    public var verified: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        role: String,
        avatarUrl: String? = nil,
        verified: Bool = true
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.avatarUrl = avatarUrl
        self.verified = verified
    }
}

public struct EventTicketModel: Identifiable, Codable, Hashable {
    public var id: String
    public var ticketCode: String
    public var eventId: String
    public var eventTitle: String
    public var eventDate: Date
    public var venueName: String
    public var attendeeId: String
    public var attendeeName: String
    public var attendeeEmail: String
    public var qrData: String
    public var pricePaidUSD: Double
    public var purchaseDate: Date
    public var isValidated: Bool
    public var seatTier: String
    
    public init(
        id: String = UUID().uuidString,
        ticketCode: String = "PRV-TCK-\(Int.random(in: 100000...999999))",
        eventId: String,
        eventTitle: String,
        eventDate: Date,
        venueName: String,
        attendeeId: String,
        attendeeName: String,
        attendeeEmail: String,
        qrData: String = "",
        pricePaidUSD: Double = 25.0,
        purchaseDate: Date = Date(),
        isValidated: Bool = false,
        seatTier: String = "General VIP"
    ) {
        self.id = id
        self.ticketCode = ticketCode
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.eventDate = eventDate
        self.venueName = venueName
        self.attendeeId = attendeeId
        self.attendeeName = attendeeName
        self.attendeeEmail = attendeeEmail
        self.qrData = qrData.isEmpty ? "PROVIWEB_TICKET:\(ticketCode)" : qrData
        self.pricePaidUSD = pricePaidUSD
        self.purchaseDate = purchaseDate
        self.isValidated = isValidated
        self.seatTier = seatTier
    }
}
