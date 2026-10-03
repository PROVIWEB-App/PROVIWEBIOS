import SwiftUI

// MARK: - User Profile & Verification View
public struct ProfileView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var selectedTab: Int = 0
    @State private var isVerificationSheetPresented: Bool = false
    @State private var isThemeSelectorPresented: Bool = false
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // User Header Card
                        VStack(spacing: 16) {
                            AvatarView(urlString: firebaseService.currentUser?.image, size: 84, isVerified: true)
                            
                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(firebaseService.currentUser?.name ?? "Israel Violín")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(theme.textPrimary)
                                    
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                Text("@\(firebaseService.currentUser?.username ?? "israviolink")")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            if let bio = firebaseService.currentUser?.bio {
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            
                            // Stats Row
                            HStack(spacing: 32) {
                                StatItem(count: "128", title: "Posts")
                                StatItem(count: "3.4k", title: "Seguidores")
                                StatItem(count: "290", title: "Siguiendo")
                            }
                            .padding(.top, 4)
                            
                            // Badges & Actions Row
                            HStack(spacing: 12) {
                                Button(action: {
                                    isVerificationSheetPresented = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "graduationcap.fill")
                                        Text("Verificaciones")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(AppColors.primary.opacity(0.12))
                                    .cornerRadius(20)
                                }
                                
                                Button(action: {
                                    isThemeSelectorPresented = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "circle.lefthalf.filled")
                                        Text("Tema: \(theme.currentTheme.title)")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(theme.backgroundColor)
                                    .cornerRadius(20)
                                }
                            }
                        }
                        .padding(20)
                        .background(theme.cardColor)
                        .cornerRadius(24)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Practice Time Badge Card
                        HStack(spacing: 14) {
                            Image(systemName: "timer")
                                .font(.title)
                                .foregroundColor(AppColors.primary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tiempo Practicado Total")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                Text("18 horas 42 minutos")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textPrimary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(theme.cardColor)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        
                        // Posts Tab Grid
                        VStack(spacing: 12) {
                            ForEach(firebaseService.posts) { post in
                                PostCardView(post: post)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Mi Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isVerificationSheetPresented) {
                VerificationRequestSheet()
            }
            .confirmationDialog("Selecciona el tema de PROVIWEB", isPresented: $isThemeSelectorPresented) {
                Button("Oscuro (Night)") { theme.currentTheme = .night }
                Button("Atenuado (Dim)") { theme.currentTheme = .dim }
                Button("Claro (Light)") { theme.currentTheme = .light }
            }
        }
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let count: String
    let title: String
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 2) {
            Text(count)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
        }
    }
}

// MARK: - Verification Request Sheet
struct VerificationRequestSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var badgeType: String = "Estudiante"
    @State private var institution: String = ""
    @State private var credentialNumber: String = ""
    @State private var isSent: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Insignia Solicitada")) {
                        Picker("Tipo de Perfil", selection: $badgeType) {
                            Text("Estudiante de Música").tag("Estudiante")
                            Text("Profesor / Maestro").tag("Profesor")
                            Text("Institución / Conservatorio / Orquesta").tag("Entidad")
                            Text("Músico / Artista Profesional").tag("Artista")
                        }
                    }
                    
                    Section(header: Text("Datos Académicos o Profesionales")) {
                        TextField("Conservatorio / Escuela / Orquesta", text: $institution)
                        TextField("Número de Matrícula o Cédula", text: $credentialNumber)
                    }
                    
                    Button(action: {
                        isSent = true
                    }) {
                        Text("Enviar Solicitud de Verificación")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Insignias Verificadas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSent) {
                Alert(
                    title: Text("Solicitud en Revisión"),
                    message: Text("El equipo de administración de PROVIWEB revisará tus credenciales en un plazo de 24 a 72 horas."),
                    dismissButton: .default(Text("Entendido")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}
