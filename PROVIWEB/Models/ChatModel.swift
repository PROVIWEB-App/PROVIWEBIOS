import Foundation

public struct ChatModel: Identifiable, Codable, Hashable {
    public var id: String
    public var userId: String
    public var userName: String
    public var userDp: String?
    public var lastMessage: String?
    public var lastTimestamp: String?
    public var unreadCount: Int?
    public var isOnline: Bool?
    public var isGroup: Bool?
    public var groupTitle: String?
    public var groupIcon: String?
    
    public init(
        id: String = UUID().uuidString,
        userId: String = "",
        userName: String = "",
        userDp: String? = nil,
        lastMessage: String? = nil,
        lastTimestamp: String? = nil,
        unreadCount: Int? = 0,
        isOnline: Bool? = false,
        isGroup: Bool? = false,
        groupTitle: String? = nil,
        groupIcon: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.userDp = userDp
        self.lastMessage = lastMessage
        self.lastTimestamp = lastTimestamp
        self.unreadCount = unreadCount
        self.isOnline = isOnline
        self.isGroup = isGroup
        self.groupTitle = groupTitle
        self.groupIcon = groupIcon
    }
}

public struct ChatMessageModel: Identifiable, Codable, Hashable {
    public var id: String
    public var messageId: String?
    public var sender: String
    public var receiver: String
    public var message: String
    public var timestamp: String?
    public var type: MessageType
    public var isSeen: Bool?
    public var mediaUrl: String?
    public var voiceDuration: Double?
    public var waveform: [Float]?
    public var splitSheet: SplitSheetAgreementModel?
    public var proposal: JobProposalModel?
    
    public init(
        id: String = UUID().uuidString,
        messageId: String? = nil,
        sender: String = "",
        receiver: String = "",
        message: String = "",
        timestamp: String? = nil,
        type: MessageType = .text,
        isSeen: Bool? = false,
        mediaUrl: String? = nil,
        voiceDuration: Double? = nil,
        waveform: [Float]? = nil,
        splitSheet: SplitSheetAgreementModel? = nil,
        proposal: JobProposalModel? = nil
    ) {
        self.id = id
        self.messageId = messageId ?? id
        self.sender = sender
        self.receiver = receiver
        self.message = message
        self.timestamp = timestamp
        self.type = type
        self.isSeen = isSeen
        self.mediaUrl = mediaUrl
        self.voiceDuration = voiceDuration
        self.waveform = waveform
        self.splitSheet = splitSheet
        self.proposal = proposal
    }
}

public enum MessageType: String, Codable {
    case text
    case image
    case audio
    case video
    case sticker
    case document
    case callMissed = "missed_call"
    case splitSheet = "split_sheet_agreement"
    case proposal = "proposal"
    case quote = "quote"
    case sheetMusic = "sheet_music"
    case song = "song"
}

// MARK: - Split-Sheet Agreement Model (com.israviolink.app.chat.DialogSplitSheetCreator)
public struct SplitSheetAgreementModel: Identifiable, Codable, Hashable {
    public var id: String
    public var agreementId: String
    public var songTitle: String
    public var genre: String
    public var creatorId: String
    public var creatorName: String
    public var creatorRole: String
    public var creatorPercentage: Int
    public var creatorSigned: Bool
    public var collaboratorId: String
    public var collaboratorName: String
    public var collaboratorRole: String
    public var collaboratorPercentage: Int
    public var collaboratorSigned: Bool
    public var status: String // "pending", "signed", "rejected"
    public var digitalCertificateHash: String
    public var createdTimestamp: Double
    
    public init(
        id: String = UUID().uuidString,
        agreementId: String = UUID().uuidString,
        songTitle: String = "",
        genre: String = "Música",
        creatorId: String = "",
        creatorName: String = "",
        creatorRole: String = "Compositor",
        creatorPercentage: Int = 50,
        creatorSigned: Bool = true,
        collaboratorId: String = "",
        collaboratorName: String = "",
        collaboratorRole: String = "Co-autor",
        collaboratorPercentage: Int = 50,
        collaboratorSigned: Bool = false,
        status: String = "pending",
        digitalCertificateHash: String = "",
        createdTimestamp: Double = Date().timeIntervalSince1970 * 1000
    ) {
        self.id = id
        self.agreementId = agreementId
        self.songTitle = songTitle
        self.genre = genre
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.creatorRole = creatorRole
        self.creatorPercentage = creatorPercentage
        self.creatorSigned = creatorSigned
        self.collaboratorId = collaboratorId
        self.collaboratorName = collaboratorName
        self.collaboratorRole = collaboratorRole
        self.collaboratorPercentage = collaboratorPercentage
        self.collaboratorSigned = collaboratorSigned
        self.status = status
        self.digitalCertificateHash = digitalCertificateHash
        self.createdTimestamp = createdTimestamp
    }
}

// MARK: - Musical Job Proposal & Gig Contract Model
public struct JobProposalModel: Identifiable, Codable, Hashable {
    public var id: String
    public var proposalId: String
    public var jobRole: String
    public var jobEvent: String
    public var jobDate: String
    public var jobLocation: String
    public var jobPrice: Double
    public var jobCurrency: String // "USD", "MXN", "QAV"
    public var jobPaymentFrequency: String // "Por Servicio", "Por Hora"
    public var jobStatus: String // "PENDING", "ACCEPTED", "REJECTED"
    public var jobDetails: String?
    
    public init(
        id: String = UUID().uuidString,
        proposalId: String = UUID().uuidString,
        jobRole: String = "Violinista Principal",
        jobEvent: String = "Boda de Gala",
        jobDate: String = "Próximo Sábado 19:00",
        jobLocation: String = "Ciudad de México",
        jobPrice: Double = 150.0,
        jobCurrency: String = "USD",
        jobPaymentFrequency: String = "Por Servicio",
        jobStatus: String = "PENDING",
        jobDetails: String? = nil
    ) {
        self.id = id
        self.proposalId = proposalId
        self.jobRole = jobRole
        self.jobEvent = jobEvent
        self.jobDate = jobDate
        self.jobLocation = jobLocation
        self.jobPrice = jobPrice
        self.jobCurrency = jobCurrency
        self.jobPaymentFrequency = jobPaymentFrequency
        self.jobStatus = jobStatus
        self.jobDetails = jobDetails
    }
}

