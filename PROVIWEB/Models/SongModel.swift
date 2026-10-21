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

    // MARK: Esquema Android (`Songs/{songId}` — MusicUploadService.java)
    /// UID del dueño de la canción (`pId` en Android).
    public var ownerId: String?
    public var album: String?
    /// Duración legible tal cual la escribe Android (`duration` = "2:15").
    public var durationText: String?
    /// Duración en milisegundos (`durationMs` de Android).
    public var durationMs: Int?
    /// Contador de reproducciones (`playCount` de Android, el que consulta MusicExploreActivity).
    public var playCount: Int?
    public var likeCount: Int?
    public var commentCount: Int?
    /// "approved" / "pending" / "rejected" (mismos valores que ModelSong.java).
    public var verificationStatus: String?
    public var rejectionReason: String?
    public var privacy: String?
    public var bpm: Int?
    /// Tonalidad (campo `key` de Android; `key` es demasiado ambiguo en Swift).
    public var musicalKey: String?
    public var instruments: String?
    public var isPromoted: Bool?
    /// Caducidad de la promoción en milisegundos (`adExpiry`).
    public var adExpiry: Double?
    public var lyrics: String?
    public var isDownloadable: Bool?
    public var downloadUrl: String?
    public var isPodcast: Bool?
    public var podcastCategory: String?
    public var hostBio: String?
    public var hostPhoto: String?
    public var sheetMusicId: String?
    public var sheetMusicTitle: String?
    public var sheetMusicUrl: String?
    public var sheetMusicCover: String?
    public var sheetMusicCategory: String?

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
        timestamp: String? = nil,
        ownerId: String? = nil,
        album: String? = nil,
        durationText: String? = nil,
        durationMs: Int? = nil,
        playCount: Int? = nil,
        likeCount: Int? = nil,
        commentCount: Int? = nil,
        verificationStatus: String? = nil,
        rejectionReason: String? = nil,
        privacy: String? = nil,
        bpm: Int? = nil,
        musicalKey: String? = nil,
        instruments: String? = nil,
        isPromoted: Bool? = nil,
        adExpiry: Double? = nil,
        lyrics: String? = nil,
        isDownloadable: Bool? = nil,
        downloadUrl: String? = nil,
        isPodcast: Bool? = nil,
        podcastCategory: String? = nil,
        hostBio: String? = nil,
        hostPhoto: String? = nil,
        sheetMusicId: String? = nil,
        sheetMusicTitle: String? = nil,
        sheetMusicUrl: String? = nil,
        sheetMusicCover: String? = nil,
        sheetMusicCategory: String? = nil
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
        self.ownerId = ownerId
        self.album = album
        self.durationText = durationText
        self.durationMs = durationMs
        self.playCount = playCount
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.verificationStatus = verificationStatus
        self.rejectionReason = rejectionReason
        self.privacy = privacy
        self.bpm = bpm
        self.musicalKey = musicalKey
        self.instruments = instruments
        self.isPromoted = isPromoted
        self.adExpiry = adExpiry
        self.lyrics = lyrics
        self.isDownloadable = isDownloadable
        self.downloadUrl = downloadUrl
        self.isPodcast = isPodcast
        self.podcastCategory = podcastCategory
        self.hostBio = hostBio
        self.hostPhoto = hostPhoto
        self.sheetMusicId = sheetMusicId
        self.sheetMusicTitle = sheetMusicTitle
        self.sheetMusicUrl = sheetMusicUrl
        self.sheetMusicCover = sheetMusicCover
        self.sheetMusicCategory = sheetMusicCategory
    }

    /// Reproducciones: prioriza el contador vivo de Android (`playCount`).
    public var totalPlays: Int { playCount ?? plays ?? 0 }

    /// Estado de moderación normalizado ("pending" cuando el nodo es antiguo).
    public var normalizedVerificationStatus: String {
        let status = (verificationStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if status == "approved" || status == "rejected" { return status }
        return "pending"
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
    /// URL del PDF: en Android es el campo `content` del nodo `books` (ArchiveActivity.java).
    public var pdfUrl: String?
    public var coverUrl: String?
    public var views: Int?

    // MARK: Esquema Android (nodo `books`)
    /// `type` de Android: "books", "booksViolin", "booksViola", "booksMGuitarra"... (BooksAdapter.java)
    public var bookType: String?
    public var isPublic: Bool?
    public var uploaderId: String?
    public var uploaderName: String?
    public var uploaderPhoto: String?
    /// Marca de tiempo en milisegundos (`timestamp` long de Android).
    public var timestamp: Double?
    public var transcriptionXml: String?
    public var transcriptionMidiCsv: String?
    public var estimatedBpm: Int?
    public var capturedNotes: Int?

    public init(
        id: String = UUID().uuidString,
        bookId: String? = nil,
        title: String = "",
        author: String = "",
        category: String? = "Violín",
        pdfUrl: String? = nil,
        coverUrl: String? = nil,
        views: Int? = 0,
        bookType: String? = nil,
        isPublic: Bool? = nil,
        uploaderId: String? = nil,
        uploaderName: String? = nil,
        uploaderPhoto: String? = nil,
        timestamp: Double? = nil,
        transcriptionXml: String? = nil,
        transcriptionMidiCsv: String? = nil,
        estimatedBpm: Int? = nil,
        capturedNotes: Int? = nil
    ) {
        self.id = id
        self.bookId = bookId ?? id
        self.title = title
        self.author = author
        self.category = category
        self.pdfUrl = pdfUrl
        self.coverUrl = coverUrl
        self.views = views
        self.bookType = bookType
        self.isPublic = isPublic
        self.uploaderId = uploaderId
        self.uploaderName = uploaderName
        self.uploaderPhoto = uploaderPhoto
        self.timestamp = timestamp
        self.transcriptionXml = transcriptionXml
        self.transcriptionMidiCsv = transcriptionMidiCsv
        self.estimatedBpm = estimatedBpm
        self.capturedNotes = capturedNotes
    }
}
