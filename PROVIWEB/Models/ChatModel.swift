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
        waveform: [Float]? = nil
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
}
