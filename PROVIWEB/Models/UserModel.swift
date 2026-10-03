import Foundation

public struct UserModel: Identifiable, Codable, Hashable {
    public var id: String
    public var uid: String?
    public var name: String
    public var email: String
    public var username: String?
    public var image: String?
    public var cover: String?
    public var bio: String?
    public var phone: String?
    public var location: String?
    public var latitude: Double?
    public var longitude: Double?
    public var verified: String? // "yes", "student", "teacher", "entity", "musician"
    public var onlineStatus: String?
    public var isTypingTo: String?
    public var instrument: String?
    public var experienceYears: Int?
    public var referralCode: String?
    public var referredBy: String?
    
    public init(
        id: String = UUID().uuidString,
        uid: String? = nil,
        name: String = "",
        email: String = "",
        username: String? = nil,
        image: String? = nil,
        cover: String? = nil,
        bio: String? = nil,
        phone: String? = nil,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        verified: String? = nil,
        onlineStatus: String? = nil,
        isTypingTo: String? = nil,
        instrument: String? = nil,
        experienceYears: Int? = nil,
        referralCode: String? = nil,
        referredBy: String? = nil
    ) {
        self.id = id
        self.uid = uid ?? id
        self.name = name
        self.email = email
        self.username = username
        self.image = image
        self.cover = cover
        self.bio = bio
        self.phone = phone
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.verified = verified
        self.onlineStatus = onlineStatus
        self.isTypingTo = isTypingTo
        self.instrument = instrument
        self.experienceYears = experienceYears
        self.referralCode = referralCode
        self.referredBy = referredBy
    }
    
    public var isVerified: Bool {
        return verified != nil && !verified!.isEmpty && verified != "no"
    }
    
    public var verificationType: VerificationType {
        guard let v = verified?.lowercased() else { return .none }
        if v.contains("student") { return .student }
        if v.contains("teacher") || v.contains("profesor") { return .teacher }
        if v.contains("entity") || v.contains("entidad") || v.contains("orquesta") { return .entity }
        if v.contains("musician") || v.contains("artista") { return .musician }
        if v == "yes" || v == "true" { return .standard }
        return .none
    }
}

public enum VerificationType: String, Codable {
    case none
    case standard
    case student
    case teacher
    case entity
    case musician
    
    public var badgeTitle: String {
        switch self {
        case .none: return ""
        case .standard: return "Verificado"
        case .student: return "Estudiante de Música"
        case .teacher: return "Profesor Certificado"
        case .entity: return "Institución Musical"
        case .musician: return "Artista / Músico"
        }
    }
    
    public var iconName: String {
        switch self {
        case .none: return ""
        case .standard: return "checkmark.seal.fill"
        case .student: return "graduationcap.fill"
        case .teacher: return "music.note.list"
        case .entity: return "building.columns.fill"
        case .musician: return "music.mic.circle.fill"
        }
    }
}
