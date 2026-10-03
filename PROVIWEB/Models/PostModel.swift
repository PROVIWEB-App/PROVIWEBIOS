import Foundation

public struct PostModel: Identifiable, Codable, Hashable {
    public var id: String
    public var pId: String?
    public var uid: String
    public var uName: String?
    public var uEmail: String?
    public var uDp: String?
    public var pTitle: String?
    public var pDescr: String?
    public var pImage: String?
    public var pVideo: String?
    public var pAudio: String?
    public var pAudioDuration: String?
    public var pTime: String?
    public var pLikes: String?
    public var pComments: String?
    public var pShare: String?
    public var feeling: String?
    public var location: String?
    public var isPromoted: Bool?
    public var likedByCurrentUser: Bool?
    public var savedByCurrentUser: Bool?
    
    public init(
        id: String = UUID().uuidString,
        pId: String? = nil,
        uid: String = "",
        uName: String? = nil,
        uEmail: String? = nil,
        uDp: String? = nil,
        pTitle: String? = nil,
        pDescr: String? = nil,
        pImage: String? = nil,
        pVideo: String? = nil,
        pAudio: String? = nil,
        pAudioDuration: String? = nil,
        pTime: String? = nil,
        pLikes: String? = "0",
        pComments: String? = "0",
        pShare: String? = "0",
        feeling: String? = nil,
        location: String? = nil,
        isPromoted: Bool? = false,
        likedByCurrentUser: Bool? = false,
        savedByCurrentUser: Bool? = false
    ) {
        self.id = id
        self.pId = pId ?? id
        self.uid = uid
        self.uName = uName
        self.uEmail = uEmail
        self.uDp = uDp
        self.pTitle = pTitle
        self.pDescr = pDescr
        self.pImage = pImage
        self.pVideo = pVideo
        self.pAudio = pAudio
        self.pAudioDuration = pAudioDuration
        self.pTime = pTime
        self.pLikes = pLikes
        self.pComments = pComments
        self.pShare = pShare
        self.feeling = feeling
        self.location = location
        self.isPromoted = isPromoted
        self.likedByCurrentUser = likedByCurrentUser
        self.savedByCurrentUser = savedByCurrentUser
    }
}

public struct ReelModel: Identifiable, Codable, Hashable {
    public var id: String
    public var reelId: String?
    public var videoUri: String
    public var thumbnail: String?
    public var caption: String?
    public var soundTitle: String?
    public var soundAuthor: String?
    public var soundUri: String?
    public var authorId: String
    public var authorName: String?
    public var authorDp: String?
    public var likesCount: Int?
    public var commentsCount: Int?
    public var viewsCount: Int?
    public var timestamp: String?
    public var isLiked: Bool?
    
    public init(
        id: String = UUID().uuidString,
        reelId: String? = nil,
        videoUri: String = "",
        thumbnail: String? = nil,
        caption: String? = nil,
        soundTitle: String? = "Sonido original",
        soundAuthor: String? = "PROVIWEB Music",
        soundUri: String? = nil,
        authorId: String = "",
        authorName: String? = nil,
        authorDp: String? = nil,
        likesCount: Int? = 0,
        commentsCount: Int? = 0,
        viewsCount: Int? = 0,
        timestamp: String? = nil,
        isLiked: Bool? = false
    ) {
        self.id = id
        self.reelId = reelId ?? id
        self.videoUri = videoUri
        self.thumbnail = thumbnail
        self.caption = caption
        self.soundTitle = soundTitle
        self.soundAuthor = soundAuthor
        self.soundUri = soundUri
        self.authorId = authorId
        self.authorName = authorName
        self.authorDp = authorDp
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.viewsCount = viewsCount
        self.timestamp = timestamp
        self.isLiked = isLiked
    }
}
