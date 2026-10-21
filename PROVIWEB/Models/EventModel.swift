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

    // MARK: - Campos del nodo RTDB de Android (`ArtisticEvents`)
    // Se añaden con valores por defecto para no romper los inits existentes de las vistas.
    public var creatorUsername: String
    /// Categoría cruda de Android (String libre: "🎵 Concierto / Música", "Teatro"...).
    public var categoryRaw: String
    public var mediaType: String          // "image" / "video"
    public var eventType: String          // "presencial" / "online"
    public var accessType: String         // "publico" / "privado"
    public var eventDateText: String      // "dd 'de' MMMM, yyyy" (legible, igual que Android)
    public var eventTime: String          // "HH:mm"
    public var eventTimestamp: Double     // long (millis) de Android
    public var onlinePlatform: String     // "PROVIWEB", "META", ...
    public var paymentMethod: String      // "qav" / "link" / "free"
    public var priceQav: Double           // precio en QAV (Android `priceQav`)
    public var purchaseLink: String
    public var createdAt: Double          // long (millis)
    public var rawStatus: String          // "active" / "cancelled" / "finished"

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
        collaborators: [EventCollaboratorItem] = [],
        creatorUsername: String = "",
        categoryRaw: String = "",
        mediaType: String = "image",
        eventType: String = "presencial",
        accessType: String = "publico",
        eventDateText: String = "",
        eventTime: String = "",
        eventTimestamp: Double = 0,
        onlinePlatform: String = "",
        paymentMethod: String = "free",
        priceQav: Double = 0,
        purchaseLink: String = "",
        createdAt: Double = 0,
        rawStatus: String = "active"
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
        self.creatorUsername = creatorUsername
        self.categoryRaw = categoryRaw
        self.mediaType = mediaType
        self.eventType = eventType
        self.accessType = accessType
        self.eventDateText = eventDateText
        self.eventTime = eventTime
        self.eventTimestamp = eventTimestamp
        self.onlinePlatform = onlinePlatform
        self.paymentMethod = paymentMethod
        self.priceQav = priceQav
        self.purchaseLink = purchaseLink
        self.createdAt = createdAt
        self.rawStatus = rawStatus
    }

    // MARK: - Helpers de interoperabilidad con Android
    /// Categoría a mostrar: el string crudo de Android si existe, si no la del enum.
    public var categoryDisplayName: String {
        categoryRaw.isEmpty ? category.rawValue : categoryRaw
    }

    /// `true` cuando el aforo está completo (`registeredCount >= maxCapacity`).
    public var isSoldOut: Bool {
        totalCapacity > 0 && ticketsSold >= totalCapacity
    }

    /// `true` cuando la entrada se paga con saldo QAV (mismo criterio de cobro en vivo).
    public var needsQavPayment: Bool {
        paymentMethod.lowercased() == "qav" && priceQav > 0
    }

    /// Evento "online" (esquema Android: `eventType = "online"`).
    public var isOnlineEvent: Bool {
        eventType.lowercased() == "online"
    }

    /// Convierte la categoría libre de Android al enum de iOS (fallback `.concert`).
    public static func mapCategory(_ raw: String) -> EventCategory {
        let text = raw.lowercased()
        guard !text.isEmpty else { return .concert }
        for cat in EventCategory.allCases where text == cat.rawValue.lowercased() {
            return cat
        }
        // Categorías del spinner de CreateEventActivity.java (Android).
        if text.contains("concierto") || text.contains("música") || text.contains("musica") { return .concert }
        if text.contains("festival") || text.contains("encuentro") || text.contains("circo") || text.contains("performance") { return .festival }
        if text.contains("teatro") || text.contains("actuación") || text.contains("actuacion") || text.contains("recital") { return .recital }
        if text.contains("masterclass") || text.contains("clase magistral") { return .masterclass }
        if text.contains("serenata") || text.contains("serenade") { return .serenade }
        if text.contains("conferencia") || text.contains("congreso") || text.contains("literatura") || text.contains("libros") || text.contains("cine") || text.contains("audiovisual") { return .conference }
        if text.contains("comedia") || text.contains("stand") || text.contains("jam") { return .jamSession }
        if text.contains("danza") || text.contains("ballet") { return .festival }
        return .concert
    }
}

public struct EventScheduleItem: Identifiable, Codable, Hashable {
    public var id: String
    public var timeString: String
    public var activityTitle: String
    public var artistName: String?
    // Campos del nodo Android `schedule`: { id, date, time, timestamp(long), accessType, title }
    public var date: String
    public var accessType: String
    public var timestamp: Double
    
    public init(
        id: String = UUID().uuidString,
        timeString: String,
        activityTitle: String,
        artistName: String? = nil,
        date: String = "",
        accessType: String = "",
        timestamp: Double = 0
    ) {
        self.id = id
        self.timeString = timeString
        self.activityTitle = activityTitle
        self.artistName = artistName
        self.date = date
        self.accessType = accessType
        self.timestamp = timestamp
    }
}

public struct EventCollaboratorItem: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var role: String
    public var avatarUrl: String?
    public var verified: Bool
    // Campos del nodo Android `collaborators`: { uid, name, username, photo, role, isAppUser }
    public var uid: String
    public var username: String
    public var isAppUser: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        role: String,
        avatarUrl: String? = nil,
        verified: Bool = true,
        uid: String = "",
        username: String = "",
        isAppUser: Bool = true
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.avatarUrl = avatarUrl
        self.verified = verified
        self.uid = uid
        self.username = username
        self.isAppUser = isAppUser
    }
}

// MARK: - Entrada del usuario (nodos Android `EventTickets` / `UserEventTickets`)
// Réplica de ModelEventTicket.java: mismos campos y tipos que escribe Android.
public struct UserEventTicketModel: Identifiable, Codable, Hashable {
    public var ticketId: String
    public var eventId: String
    public var eventTitle: String
    public var eventCategory: String
    public var eventDateText: String   // eventDate legible "dd 'de' MMMM, yyyy"
    public var eventTime: String       // "HH:mm"
    public var eventTimestamp: Double  // long (millis)
    public var eventLocation: String   // "Online: PROVIWEB" o la sede
    public var eventCoverUrl: String?
    public var eventType: String       // "presencial" / "online"
    public var userId: String
    public var userName: String
    public var userUsername: String
    public var userPhoto: String?
    public var creatorId: String
    public var pricePaidQav: Double
    public var paymentMethod: String   // "qav" / "link" / "free"
    public var qrPayload: String       // "PROVIWEB_TICKET:eventId:ticketId:userId"
    public var purchasedAtMs: Double   // long (millis)
    public var checkedIn: Bool
    public var checkedInAtMs: Double   // long (millis)

    public var id: String { ticketId }

    public init(
        ticketId: String,
        eventId: String,
        eventTitle: String,
        eventCategory: String = "",
        eventDateText: String = "",
        eventTime: String = "",
        eventTimestamp: Double = 0,
        eventLocation: String = "",
        eventCoverUrl: String? = nil,
        eventType: String = "presencial",
        userId: String,
        userName: String,
        userUsername: String = "",
        userPhoto: String? = nil,
        creatorId: String = "",
        pricePaidQav: Double = 0,
        paymentMethod: String = "free",
        qrPayload: String = "",
        purchasedAtMs: Double = 0,
        checkedIn: Bool = false,
        checkedInAtMs: Double = 0
    ) {
        self.ticketId = ticketId
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.eventCategory = eventCategory
        self.eventDateText = eventDateText
        self.eventTime = eventTime
        self.eventTimestamp = eventTimestamp
        self.eventLocation = eventLocation
        self.eventCoverUrl = eventCoverUrl
        self.eventType = eventType
        self.userId = userId
        self.userName = userName
        self.userUsername = userUsername
        self.userPhoto = userPhoto
        self.creatorId = creatorId
        self.pricePaidQav = pricePaidQav
        self.paymentMethod = paymentMethod
        self.qrPayload = qrPayload
        self.purchasedAtMs = purchasedAtMs
        self.checkedIn = checkedIn
        self.checkedInAtMs = checkedInAtMs
    }

    /// Fecha/hora del evento ya resueltas desde `eventTimestamp` (como hace Android al pintar el ticket).
    public var eventDate: Date {
        if eventTimestamp > 0 {
            return Date(timeIntervalSince1970: eventTimestamp / 1000)
        }
        return Date(timeIntervalSince1970: purchasedAtMs / 1000)
    }

    /// Convierte a `EventTicketModel` para las vistas de boleto digital:
    /// `qrData` conserva el `qrPayload` real de Android y `isValidated` refleja `checkedIn`.
    public func asDisplayTicket() -> EventTicketModel {
        EventTicketModel(
            id: ticketId,
            ticketCode: ticketId,
            eventId: eventId,
            eventTitle: eventTitle,
            eventDate: eventDate,
            venueName: eventLocation,
            attendeeId: userId,
            attendeeName: userName,
            attendeeEmail: "",
            qrData: qrPayload,
            pricePaidUSD: pricePaidQav,
            purchaseDate: purchasedAtMs > 0 ? Date(timeIntervalSince1970: purchasedAtMs / 1000) : Date(),
            isValidated: checkedIn,
            seatTier: eventCategory.isEmpty ? "Entrada" : eventCategory
        )
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
