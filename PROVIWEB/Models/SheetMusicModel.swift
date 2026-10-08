import Foundation

// MARK: - Sheet Music, Partituras Archive & Score Models
public struct SheetMusicItemModel: Identifiable, Codable, Hashable {
    public var id: String
    public var title: String
    public var composer: String
    public var arranger: String?
    public var genre: MusicalGenre
    public var instrument: MusicalInstrument
    public var difficulty: DifficultyLevel
    public var keySignature: String
    public var tempoBpm: Int
    public var pagesCount: Int
    public var pdfUrl: String
    public var audioBackingTrackUrl: String?
    public var coverImageUrl: String?
    public var downloadCount: Int
    public var isFavorite: Bool
    public var tags: [String]
    
    public enum MusicalGenre: String, Codable, CaseIterable {
        case classical = "Clásico"
        case mariachi = "Mariachi"
        case banda = "Banda & Regional"
        case jazz = "Jazz & Ensamble"
        case popular = "Popular & Cuerdas"
    }
    
    public enum MusicalInstrument: String, Codable, CaseIterable {
        // Cuerdas
        case violin = "Violín"
        case viola = "Viola"
        case violoncello = "Violonchelo"
        case contrabass = "Contrabajo"
        // Mariachi / Cuerdas tradicionales
        case vihuela = "Vihuela"
        case guitarron = "Guitarrón"
        case arpa = "Arpa"
        case guitarra = "Guitarra"
        // Vientos Madera
        case flauta = "Flauta"
        case oboe = "Oboe"
        case clarinete = "Clarinete"
        case saxofon = "Saxofón"
        case fagot = "Fagot"
        // Vientos Metal
        case trompeta = "Trompeta"
        case trombon = "Trombón"
        case corno = "Corno Francés"
        case tuba = "Tuba"
        // Teclados & Percusión
        case piano = "Piano"
        case timpani = "Timpani / Batería"
        case voz = "Voz / Coro"
        case scoreGeneral = "Partitura General (Score)"
    }
    
    public enum DifficultyLevel: String, Codable, CaseIterable {
        case beginner = "Principiante"
        case intermediate = "Intermedio"
        case advanced = "Avanzado"
        case virtuoso = "Virtuoso / Profesional"
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        composer: String,
        arranger: String? = nil,
        genre: MusicalGenre = .classical,
        instrument: MusicalInstrument = .violin,
        difficulty: DifficultyLevel = .intermediate,
        keySignature: String = "Re Mayor (D Major)",
        tempoBpm: Int = 120,
        pagesCount: Int = 4,
        pdfUrl: String = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
        audioBackingTrackUrl: String? = nil,
        coverImageUrl: String? = nil,
        downloadCount: Int = 120,
        isFavorite: Bool = false,
        tags: [String] = ["Repertorio", "Estudio", "Concierto"]
    ) {
        self.id = id
        self.title = title
        self.composer = composer
        self.arranger = arranger
        self.genre = genre
        self.instrument = instrument
        self.difficulty = difficulty
        self.keySignature = keySignature
        self.tempoBpm = tempoBpm
        self.pagesCount = pagesCount
        self.pdfUrl = pdfUrl
        self.audioBackingTrackUrl = audioBackingTrackUrl
        self.coverImageUrl = coverImageUrl
        self.downloadCount = downloadCount
        self.isFavorite = isFavorite
        self.tags = tags
    }
}
