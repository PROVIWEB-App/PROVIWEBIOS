import SwiftUI

// MARK: - Music Explore & Genre Catalog View
public struct MusicExploreView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedGenre: String = "Todos"
    @State private var isUploadSongPresented: Bool = false
    @State private var isCreatePlaylistPresented: Bool = false
    
    public let genres = [
        ("Todos", "music.note.list", AppColors.primary),
        ("Música Clásica", "violin.fill", Color.indigo),
        ("Mariachi", "music.mic.circle.fill", AppColors.gold),
        ("Banda Sinaloense", "speaker.wave.3.fill", Color.orange),
        ("Jazz", "pianokeys", Color.purple),
        ("Canto Lírico", "waveform.circle.fill", AppColors.success)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Top Actions Bar (Upload & Create Playlist)
                        HStack(spacing: 12) {
                            Button(action: {
                                isUploadSongPresented = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Subir Canción")
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppColors.primary)
                                .cornerRadius(14)
                            }
                            
                            Button(action: {
                                isCreatePlaylistPresented = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.rectangle.on.rectangle")
                                    Text("Crear Playlist")
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(theme.cardColor)
                                .cornerRadius(14)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Genre Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(genres, id: \.0) { genre in
                                    Button(action: {
                                        selectedGenre = genre.0
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: genre.1)
                                            Text(genre.0)
                                        }
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedGenre == genre.0 ? .white : theme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedGenre == genre.0 ? genre.2 : theme.cardColor)
                                        .cornerRadius(18)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Featured Tracks List
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Pistas Destacadas")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 16)
                            
                            ForEach(firebaseService.songs) { song in
                                SongExploreRow(song: song) {
                                    player.playSong(song)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Explorar Música")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isUploadSongPresented) {
                UploadSongView()
            }
            .sheet(isPresented: $isCreatePlaylistPresented) {
                CreatePlaylistView()
            }
        }
    }
}

// MARK: - Song Explore Row
struct SongExploreRow: View {
    let song: SongModel
    let onPlay: () -> Void
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                ZStack {
                    if let cover = song.coverUrl, let url = URL(string: cover) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(AppColors.musicPrimary.opacity(0.3))
                        }
                        .frame(width: 54, height: 54)
                        .cornerRadius(12)
                    }
                    
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                
                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(song.genre ?? "Clásica")
                    .font(.caption2)
                    .foregroundColor(AppColors.primary)
                
                Text("\(song.plays ?? 0) reproducciones")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(12)
        .background(theme.cardColor)
        .cornerRadius(16)
    }
}

// MARK: - Upload Song View
struct UploadSongView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var songTitle: String = ""
    @State private var genre: String = "Clásica"
    @State private var isOwnSongConfirmed: Bool = true
    @State private var isSuccess: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Información de la Canción")) {
                        TextField("Título de la obra o canción", text: $songTitle)
                        Picker("Género Musical", selection: $genre) {
                            Text("Música Clásica").tag("Clásica")
                            Text("Mariachi").tag("Mariachi")
                            Text("Banda Sinaloense").tag("Banda")
                            Text("Jazz").tag("Jazz")
                            Text("Vocal / Canto").tag("Vocal")
                        }
                    }
                    
                    Section(header: Text("Archivo de Audio")) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "waveform.circle.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("Seleccionar Archivo (MP3 / WAV)")
                            }
                        }
                    }
                    
                    Section(header: Text("Verificación de Autoría")) {
                        Toggle("Declaro que soy el autor o cuento con los derechos de esta grabación", isOn: $isOwnSongConfirmed)
                    }
                    
                    Button(action: {
                        isSuccess = true
                    }) {
                        Text("Subir a PROVIWEB")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Subir Canción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSuccess) {
                Alert(title: Text("Canción Enviada"), message: Text("Tu pista se ha subido y pasará por revisión de derechos."), dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
    }
}

// MARK: - Create Playlist View
struct CreatePlaylistView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var playlistName: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Nombre de la Playlist")) {
                        TextField("Ej: Mis Favoritas de Violín", text: $playlistName)
                    }
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Crear Playlist")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Nueva Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
