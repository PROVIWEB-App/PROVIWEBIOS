import Foundation

// MARK: - Masterclasses, Private Lessons & Teacher Availability Models
public struct TeacherModel: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var username: String
    public var avatarUrl: String?
    public var instrument: String
    public var bio: String
    public var hourlyRateUSD: Double
    public var hourlyRateDiamonds: Int
    public var rating: Double
    public var reviewCount: Int
    public var experienceYears: Int
    public var institution: String
    public var modality: LessonModality
    public var availableDays: [String]
    public var timeSlots: [ClassTimeSlot]
    public var isVerifiedTeacher: Bool
    
    public enum LessonModality: String, Codable, CaseIterable {
        case online = "En Línea (Video)"
        case inPerson = "Presencial"
        case hybrid = "Híbrido"
    }
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        username: String,
        avatarUrl: String? = nil,
        instrument: String,
        bio: String,
        hourlyRateUSD: Double = 35.0,
        hourlyRateDiamonds: Int = 200,
        rating: Double = 4.9,
        reviewCount: Int = 38,
        experienceYears: Int = 10,
        institution: String = "Conservatorio Nacional",
        modality: LessonModality = .online,
        availableDays: [String] = ["Lunes", "Miércoles", "Viernes", "Sábado"],
        timeSlots: [ClassTimeSlot] = [],
        isVerifiedTeacher: Bool = true
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.avatarUrl = avatarUrl
        self.instrument = instrument
        self.bio = bio
        self.hourlyRateUSD = hourlyRateUSD
        self.hourlyRateDiamonds = hourlyRateDiamonds
        self.rating = rating
        self.reviewCount = reviewCount
        self.experienceYears = experienceYears
        self.institution = institution
        self.modality = modality
        self.availableDays = availableDays
        self.timeSlots = timeSlots
        self.isVerifiedTeacher = isVerifiedTeacher
    }
}

public struct ClassTimeSlot: Identifiable, Codable, Hashable {
    public var id: String
    public var dayOfWeek: String
    public var startTime: String
    public var endTime: String
    public var isAvailable: Bool
    
    public init(
        id: String = UUID().uuidString,
        dayOfWeek: String,
        startTime: String,
        endTime: String,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.startTime = startTime
        self.endTime = endTime
        self.isAvailable = isAvailable
    }
}

public struct BookedClassModel: Identifiable, Codable, Hashable {
    public var id: String
    public var teacherId: String
    public var teacherName: String
    public var teacherAvatar: String?
    public var studentId: String
    public var studentName: String
    public var studentAvatar: String?
    public var instrument: String
    public var scheduledDate: Date
    public var startTime: String
    public var endTime: String
    public var modality: TeacherModel.LessonModality
    public var lessonTopic: String
    public var priceUSD: Double
    public var status: BookingStatus
    public var videoRoomId: String?
    public var notes: String?
    
    public enum BookingStatus: String, Codable {
        case pending = "Pendiente de Confirmación"
        case confirmed = "Confirmada"
        case ongoing = "En Curso"
        case completed = "Completada"
        case cancelled = "Cancelada"
    }
    
    public init(
        id: String = UUID().uuidString,
        teacherId: String,
        teacherName: String,
        teacherAvatar: String? = nil,
        studentId: String,
        studentName: String,
        studentAvatar: String? = nil,
        instrument: String,
        scheduledDate: Date = Date().addingTimeInterval(86400 * 2),
        startTime: String = "16:00",
        endTime: String = "17:00",
        modality: TeacherModel.LessonModality = .online,
        lessonTopic: String = "Técnica de Afinación y Postura de Arco",
        priceUSD: Double = 35.0,
        status: BookingStatus = .confirmed,
        videoRoomId: String? = "room_masterclass_\(Int.random(in: 100...999))",
        notes: String? = nil
    ) {
        self.id = id
        self.teacherId = teacherId
        self.teacherName = teacherName
        self.teacherAvatar = teacherAvatar
        self.studentId = studentId
        self.studentName = studentName
        self.studentAvatar = studentAvatar
        self.instrument = instrument
        self.scheduledDate = scheduledDate
        self.startTime = startTime
        self.endTime = endTime
        self.modality = modality
        self.lessonTopic = lessonTopic
        self.priceUSD = priceUSD
        self.status = status
        self.videoRoomId = videoRoomId
        self.notes = notes
    }
}
