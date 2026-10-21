import SwiftUI

// MARK: - Sheet Music Archive & Score Library View
public struct SheetMusicArchiveView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedGenre: SheetMusicItemModel.MusicalGenre? = nil
    @State private var selectedInstrument: SheetMusicItemModel.MusicalInstrument = .violin
    @State private var searchText: String = ""
    @State private var selectedScoreForViewer: SheetMusicItemModel? = nil
    
    /// Semilla local: se muestra como "Ejemplos" cuando el nodo `books` está vacío
    /// (modo demo / sin sesión / base sin datos).
    private let exampleScores: [SheetMusicItemModel] = [
        SheetMusicItemModel(
            title: "Czardas",
            composer: "Vittorio Monti",
            arranger: "Israel Violín (Edición con Digitaciones)",
            genre: .classical,
            instrument: .violin,
            difficulty: .advanced,
            keySignature: "Re Menor (D Minor)",
            tempoBpm: 140,
            pagesCount: 6,
            pdfUrl: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
            audioBackingTrackUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
            downloadCount: 340,
            isFavorite: true,
            tags: ["Czardas", "Monti", "Virtuoso", "Gipsy"]
        ),
        SheetMusicItemModel(
            title: "Concierto para Violín en Mi Menor, Op. 64",
            composer: "Felix Mendelssohn",
            arranger: "Partitura Urtext con Cadencia",
            genre: .classical,
            instrument: .violin,
            difficulty: .virtuoso,
            keySignature: "Mi Menor (E Minor)",
            tempoBpm: 128,
            pagesCount: 24,
            pdfUrl: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
            audioBackingTrackUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
            downloadCount: 890,
            isFavorite: true,
            tags: ["Mendelssohn", "Concierto", "Romántico"]
        ),
        SheetMusicItemModel(
            title: "El Son de la Negra (Partitura para Mariachi)",
            composer: "Tradicional Jalisciense",
            arranger: "Arreglo para Violines I y II",
            genre: .mariachi,
            instrument: .violin,
            difficulty: .intermediate,
            keySignature: "Sol Mayor (G Major)",
            tempoBpm: 156,
            pagesCount: 3,
            pdfUrl: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
            audioBackingTrackUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
            downloadCount: 1240,
            isFavorite: false,
            tags: ["Mariachi", "Violín", "Son de la Negra", "México"]
        ),
        SheetMusicItemModel(
            title: "Guadalajara",
            composer: "Pepe Guízar",
            arranger: "Partitura General de Trompetas y Violines",
            genre: .mariachi,
            instrument: .trompeta,
            difficulty: .intermediate,
            keySignature: "Do Mayor (C Major)",
            tempoBpm: 132,
            pagesCount: 4,
            pdfUrl: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
            downloadCount: 650,
            isFavorite: false,
            tags: ["Mariachi", "Trompeta", "Jalisco"]
        ),
        SheetMusicItemModel(
            title: "Autumn Leaves (Hojas Muertas)",
            composer: "Joseph Kosma",
            arranger: "Arreglo Jazz con Cifrado y Melodía",
            genre: .jazz,
            instrument: .piano,
            difficulty: .intermediate,
            keySignature: "Sol Menor (G Minor)",
            tempoBpm: 110,
            pagesCount: 5,
            pdfUrl: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
            downloadCount: 480,
            isFavorite: false,
            tags: ["Jazz", "Piano", "Standards"]
        ),
        SheetMusicItemModel(
            title: "El Sinaloense",
            composer: "Severiano Briseño",
            arranger: "Score Completo para Banda",
            genre: .banda,
            instrument: .trombon,
            difficulty: .advanced,
            keySignature: "Si Bemol Mayor (Bb Major)",
            tempoBpm: 160,
            pagesCount: 4,
            pdfUrl: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
            downloadCount: 710,
            isFavorite: false,
            tags: ["Banda", "Trombón", "Sinaloa"]
        )
    ]
    
    public init() {}
    
    /// Catálogo real (`books` del nodo de Android). Si está vacío se muestran los ejemplos.
    private var scores: [SheetMusicItemModel] {
        firebaseService.books.isEmpty
            ? exampleScores
            : firebaseService.books.map(Self.score(from:))
    }
    
    /// `true` cuando no hay datos reales en la nube (la lista es la semilla de ejemplo).
    private var isShowingExamples: Bool { firebaseService.books.isEmpty }
    
    /// `BookModel` (nodo `books`, esquema de ArchiveActivity.java) → partitura navegable.
    private static func score(from book: BookModel) -> SheetMusicItemModel {
        // `type` ("books", "booksViolin", "booksMGuitarra"...) + categoría del nodo.
        let tags = "\(book.bookType ?? "") \(book.category ?? "")".lowercased()
        
        let instrument: SheetMusicItemModel.MusicalInstrument
        if tags.contains("violonchelo") || tags.contains("cello") {
            instrument = .violoncello
        } else if tags.contains("viola") {
            instrument = .viola
        } else if tags.contains("violin") {
            instrument = .violin
        } else if tags.contains("guitarra") {
            instrument = .guitarra
        } else if tags.contains("piano") {
            instrument = .piano
        } else if tags.contains("trompeta") {
            instrument = .trompeta
        } else if tags.contains("flauta") {
            instrument = .flauta
        } else {
            instrument = .scoreGeneral
        }
        
        let genre: SheetMusicItemModel.MusicalGenre
        if tags.contains("mariachi") {
            genre = .mariachi
        } else if tags.contains("banda") {
            genre = .banda
        } else if tags.contains("jazz") {
            genre = .jazz
        } else if tags.contains("popular") || tags.contains("pop") {
            genre = .popular
        } else {
            genre = .classical
        }
        
        return SheetMusicItemModel(
            id: book.id,
            title: book.title,
            composer: book.author,
            genre: genre,
            instrument: instrument,
            // Los libros de Android no traen tonalidad ni nº de páginas: se omiten en la fila.
            keySignature: "",
            tempoBpm: book.estimatedBpm ?? 0,
            pagesCount: 0,
            // `content` de Android es la URL del PDF (visor existente SheetMusicPDFViewer).
            pdfUrl: book.pdfUrl ?? "",
            coverImageUrl: book.coverUrl,
            downloadCount: 0,
            tags: [book.category ?? "Partituras"]
        )
    }
    
    public var filteredScores: [SheetMusicItemModel] {
        scores.filter { score in
            let matchesGenre = selectedGenre == nil || score.genre == selectedGenre
            let matchesInstrument = score.instrument == selectedInstrument
            let matchesSearch = searchText.isEmpty ||
                score.title.localizedCaseInsensitiveContains(searchText) ||
                score.composer.localizedCaseInsensitiveContains(searchText)
            
            return matchesGenre && (selectedGenre != nil ? matchesInstrument : true) && matchesSearch
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top App Bar
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(theme.textPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Biblioteca de Partituras")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            Text(isShowingExamples ? "Ejemplos de la colección" : "Partituras de la comunidad PROVIWEB")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "music.note.list")
                            .foregroundColor(AppColors.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.cardColor)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(theme.textSecondary)
                        TextField("Buscar partituras por título, compositor...", text: $searchText)
                            .foregroundColor(theme.textPrimary)
                    }
                    .padding(10)
                    .background(theme.backgroundColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    // Genre Selector Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: { selectedGenre = nil }) {
                                Text("Todos los Géneros")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(selectedGenre == nil ? .white : theme.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedGenre == nil ? AppColors.primary : theme.cardColor)
                                    .cornerRadius(16)
                            }
                            
                            ForEach(SheetMusicItemModel.MusicalGenre.allCases, id: \.self) { genre in
                                Button(action: { selectedGenre = genre }) {
                                    Text(genre.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedGenre == genre ? .white : theme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedGenre == genre ? AppColors.primary : theme.cardColor)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    
                    // Instrument Selector Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([
                                SheetMusicItemModel.MusicalInstrument.violin,
                                SheetMusicItemModel.MusicalInstrument.viola,
                                SheetMusicItemModel.MusicalInstrument.violoncello,
                                SheetMusicItemModel.MusicalInstrument.guitarron,
                                SheetMusicItemModel.MusicalInstrument.vihuela,
                                SheetMusicItemModel.MusicalInstrument.trompeta,
                                SheetMusicItemModel.MusicalInstrument.trombon,
                                SheetMusicItemModel.MusicalInstrument.piano,
                                SheetMusicItemModel.MusicalInstrument.saxofon,
                                SheetMusicItemModel.MusicalInstrument.flauta,
                                SheetMusicItemModel.MusicalInstrument.scoreGeneral
                            ], id: \.self) { inst in
                                Button(action: { selectedInstrument = inst }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "music.quarternote.3")
                                            .font(.caption2)
                                        Text(inst.rawValue)
                                    }
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedInstrument == inst ? AppColors.primary : theme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedInstrument == inst ? AppColors.primary.opacity(0.15) : theme.cardColor)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    
                    // Scores List
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredScores) { score in
                                SheetMusicRowItem(score: score) {
                                    // Solo abre el visor si hay PDF real (nodo `content` de Android).
                                    guard !score.pdfUrl.isEmpty else { return }
                                    selectedScoreForViewer = score
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedScoreForViewer) { score in
                SheetMusicPDFViewer(score: score)
            }
        }
    }
}

// MARK: - Sheet Music Row Item
struct SheetMusicRowItem: View {
    let score: SheetMusicItemModel
    let onTap: () -> Void
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // PDF / Score Icon Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.primary.opacity(0.12))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(score.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                    
                    Text(score.composer)
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                    
                    HStack(spacing: 8) {
                        Text(score.instrument.rawValue)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primary)
                        
                        if !score.keySignature.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                            
                            Text(score.keySignature)
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                        }
                        
                        if score.tempoBpm > 0 {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                            
                            Text("\(score.tempoBpm) BPM")
                                .font(.caption2)
                                .foregroundColor(AppColors.gold)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    if score.pagesCount > 0 {
                        Text("\(score.pagesCount) pág.")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(14)
            .background(theme.cardColor)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
