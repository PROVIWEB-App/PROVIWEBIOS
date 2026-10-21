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
    /// `MutedChats/{miUid}/{userId}` — silenciado visto en la fila (AdapterChatList en Android).
    public var isMuted: Bool?
    
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
        groupIcon: String? = nil,
        isMuted: Bool? = nil
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
        self.isMuted = isMuted
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
    /// Reacciones en vivo: `Chats/{msgId}/reactions/{uid}` = emoji (AdapterChat.java).
    public var reactions: [String: String]?
    
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
        reactions: [String: String]? = nil
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
        self.reactions = reactions
    }
}

/// Catálogo de tipos de mensaje — mantiene los rawValues del nodo `Chats.type` de Android
/// (`ChatActivity.java`), incluyendo los alias legados ("doc") y los tipos enriquecidos.
/// Los valores no reconocidos se decodifican como `.unknown` para no romper el hilo.
public enum MessageType: String, Codable {
    case text
    case image
    case audio
    case video
    case sticker
    case document
    case doc = "doc"
    case location
    case gif
    case gift
    case callMissed = "missed_call"
    case voiceCall = "voice_call"
    case audioCall = "audio_call"
    case videoCall = "video_call"
    case call = "call"
    case jobProposal = "job_proposal"
    case sheetMusic = "sheet_music"
    case song
    case meet
    case meeting
    case meetingPresential = "meeting_presential"
    case reel
    case post
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = MessageType(rawValue: raw) ?? .unknown
    }

    /// Preview formateado del último mensaje para la bandeja (`AdapterChatList` en Android).
    public var inboxPreviewLabel: String? {
        switch self {
        case .text, .unknown: return nil
        case .image: return "📷 Foto"
        case .video: return "🎥 Video"
        case .audio: return "🎤 Audio"
        case .doc, .document: return "📄 Documento"
        case .location: return "📍 Ubicación"
        case .sticker: return "Sticker"
        case .gif: return "GIF"
        case .gift: return "🎁 Regalo"
        case .song: return "🎵 Canción"
        case .sheetMusic: return "🎼 Partitura"
        case .jobProposal: return "💼 Propuesta"
        case .meet, .meeting, .meetingPresential: return "📹 Reunión"
        case .reel: return "🎬 Reel"
        case .post: return "📝 Publicación"
        case .callMissed: return "📵 Llamada perdida"
        case .voiceCall: return "📞 Llamada de voz"
        case .audioCall: return "📞 Llamada de audio"
        case .videoCall: return "📹 Videollamada"
        case .call: return "📞 Llamada"
        }
    }
}

public extension ChatMessageModel {
    /// Reacciones agrupadas por emoji, como `AdapterChat.java` (161-176): cuenta
    /// `reactions.values()` y pinta "emoji n". Orden estable: primero las más votadas.
    var groupedReactions: [(emoji: String, count: Int)] {
        guard let reactions = reactions, !reactions.isEmpty else { return [] }
        var counts: [String: Int] = [:]
        for emoji in reactions.values {
            counts[emoji, default: 0] += 1
        }
        return counts
            .map { (emoji: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs.emoji < rhs.emoji : lhs.count > rhs.count
            }
    }
}
