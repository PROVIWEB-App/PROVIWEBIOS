import SwiftUI

// MARK: - Bottom Sheet Creation Options Modal
public struct CreateModalSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public var onSelectOption: (CreateOption) -> Void
    
    public enum CreateOption {
        case post
        case reel
        case aiProfessor
        case practice
        case music
        case sell
        case quotes
        case wallet
        case invite
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Drag indicator
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            Text("¿Qué deseas crear o explorar?")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                CreateOptionItem(title: "Publicación", icon: "square.and.pencil", color: AppColors.primary) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectOption(.post)
                }
                
                CreateOptionItem(title: "Reel Musical", icon: "film.fill", color: .purple) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectOption(.reel)
                }
                
                CreateOptionItem(title: "Profesor IA", icon: "brain.head.profile", color: AppColors.primaryDark) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectOption(.aiProfessor)
                }
                
                CreateOptionItem(title: "Estudio Práctica", icon: "metronome.fill", color: AppColors.gold) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectOption(.practice)
                }
                
                CreateOptionItem(title: "Música", icon: "music.note.list", color: AppColors.musicPrimary) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectOption(.music)
                }
                
                CreateOptionItem(title: "Vender", icon: "tag.fill", color: AppColors.success) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectOption(.sell)
                }
                
                CreateOptionItem(title: "Cotizaciones", icon: "music.mic.circle.fill", color: AppColors.warningOrange) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectOption(.quotes)
                }
                
                CreateOptionItem(title: "Monedero QAV", icon: "wallet.pass.fill", color: AppColors.chatPrimary) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectOption(.wallet)
                }
                
                CreateOptionItem(title: "Invitar y Ganar", icon: "person.badge.plus", color: .indigo) {
                    presentationMode.wrappedValue.dismiss()
                    onSelectOption(.invite)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(theme.cardColor)
        .cornerRadius(24)
    }
}

// MARK: - Create Option Item
struct CreateOptionItem: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 58, height: 58)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Create Post View Composer
public struct CreatePostView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var postTitle: String = ""
    @State private var postDescription: String = ""
    @State private var selectedFeeling: String = "Inspirado"
    @State private var selectedLocation: String = "Ciudad de México"
    
    let feelings = ["Inspirado", "Feliz", "Practicando", "En Concierto", "En Estudio", "Emocionado"]
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // User Header
                    HStack(spacing: 12) {
                        AvatarView(urlString: firebaseService.currentUser?.image, size: 44, isVerified: true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(firebaseService.currentUser?.name ?? "Israel Violín")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            HStack {
                                Menu {
                                    ForEach(feelings, id: \.self) { feeling in
                                        Button(action: { selectedFeeling = feeling }) {
                                            Text(feeling)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("Me siento \(selectedFeeling)")
                                        Image(systemName: "chevron.down")
                                    }
                                    .font(.caption)
                                    .foregroundColor(AppColors.primary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Post Fields
                    TextField("Título de tu práctica o pieza musical...", text: $postTitle)
                        .font(.headline)
                        .padding(12)
                        .background(theme.cardColor)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    
                    TextEditor(text: $postDescription)
                        .font(.body)
                        .padding(8)
                        .background(theme.cardColor)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .frame(height: 140)
                    
                    // Attachment Actions
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.fill")
                                    .foregroundColor(AppColors.success)
                                Text("Foto")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(theme.cardColor)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {}) {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .foregroundColor(AppColors.primary)
                                Text("Pista Audio")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(theme.cardColor)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {}) {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(AppColors.errorRed)
                                Text("Ubicación")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(theme.cardColor)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    Button(action: {
                        firebaseService.createPost(
                            title: postTitle,
                            description: postDescription,
                            feeling: selectedFeeling,
                            image: "https://images.unsplash.com/photo-1612225330812-01a9c6b355ec?w=800&auto=format&fit=crop&q=60",
                            video: nil,
                            audio: nil
                        )
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Publicar en PROVIWEB")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.primary)
                            .cornerRadius(16)
                            .shadow(color: AppColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Crear Publicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
