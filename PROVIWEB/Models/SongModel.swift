import Foundation

public struct SongModel: Identifiable, Codable, Hashable {
    public var id: String
    public var songId: String?
    public var title: String
    public var artist: String
    public var artistId: String?
    public var audioUrl: String
    public var coverUrl: String?
    public var genre: String?
    public var duration: Double? // Duration in seconds
    public var plays: Int?
    public var isVerifiedAuthor: Bool?
    public var isPendingReview: Bool?
    public var timestamp: String?
    
    public init(
        id: String = UUID().uuidString,
        songId: String? = nil,
        title: String = "",
        artist: String = "",
        artistId: String? = nil,
        audioUrl: String = "",
        coverUrl: String? = nil,
        genre: String? = "Clásica",
        duration: Double? = 0,
        plays: Int? = 0,
        isVerifiedAuthor: Bool? = true,
        isPendingReview: Bool? = false,
        timestamp: String? = nil
    ) {
        self.id = id
        self.songId = songId ?? id
        self.title = title
        self.artist = artist
        self.artistId = artistId
        self.audioUrl = audioUrl
        self.coverUrl = coverUrl
        self.genre = genre
        self.duration = duration
        self.plays = plays
        self.isVerifiedAuthor = isVerifiedAuthor
        self.isPendingReview = isPendingReview
        self.timestamp = timestamp
    }
}

public struct PlaylistModel: Identifiable, Codable, Hashable {
    public var id: String
    public var playlistId: String?
    public var title: String
    public var coverUrl: String?
    public var creatorId: String?
    public var creatorName: String?
    public var songsCount: Int?
    public var songs: [SongModel]?
    
    public init(
        id: String = UUID().uuidString,
        playlistId: String? = nil,
        title: String = "",
        coverUrl: String? = nil,
        creatorId: String? = nil,
        creatorName: String? = nil,
        songsCount: Int? = 0,
        songs: [SongModel]? = []
    ) {
        self.id = id
        self.playlistId = playlistId ?? id
        self.title = title
        self.coverUrl = coverUrl
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.songsCount = songsCount
        self.songs = songs
    }
}

public struct BookModel: Identifiable, Codable, Hashable {
    public var id: String
    public var bookId: String?
    public var title: String
    public var author: String
    public var category: String?
    public var pdfUrl: String?
    public var coverUrl: String?
    public var views: Int?
    
    public init(
        id: String = UUID().uuidString,
        bookId: String? = nil,
        title: String = "",
        author: String = "",
        category: String? = "Violín",
        pdfUrl: String? = nil,
        coverUrl: String? = nil,
        views: Int? = 0
    ) {
        self.id = id
        self.bookId = bookId ?? id
        self.title = title
        self.author = author
        self.category = category
        self.pdfUrl = pdfUrl
        self.coverUrl = coverUrl
        self.views = views
    }
}
