import SwiftUI

// MARK: - Full Side Navigation Drawer Menu
public struct SideDrawerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isExplorePresented: Bool = false
    @State private var isSheetMusicPresented: Bool = false
    @State private var isEventsPresented: Bool = false
    @State private var isClassesPresented: Bool = false
    @State private var isMusicalHubPresented: Bool = false
    @State private var isGamesPresented: Bool = false
    @State private var isPagesPresented: Bool = false
    @State private var isMeetingPresented: Bool = false
    @State private var isWalletPresented: Bool = false
    @State private var isInvitePresented: Bool = false
    @State private var isNotificationsPresented: Bool = false
    @State private var isSocialInsightsPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isAdminPresented: Bool = false
    @State private var isThemeDialogPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // User Profile Summary Header
                        Button(action: { isSocialInsightsPresented = true }) {
                            HStack(spacing: 14) {
                                AvatarView(urlString: firebaseService.currentUser?.image, size: 56, isVerified: true)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(firebaseService.currentUser?.name ?? "Israel Violín")
                                        .font(.headline)
                                        .foregroundColor(theme.textPrimary)
                                    
                                    Text("@\(firebaseService.currentUser?.username ?? "israviolink")")
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                    
                                    Text("Saldo: \(String(format: "$%.2f USD", firebaseService.walletBalance.balanceUSD)) (\(firebaseService.walletBalance.diamonds) 💎)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            .padding(16)
                            .background(theme.cardColor)
                            .cornerRadius(20)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Core Music & Community Modules
                        VStack(spacing: 4) {
                            DrawerRow(title: "Eventos Artísticos & Boletos", icon: "ticket.fill", color: Color.purple) {
                                isEventsPresented = true
                            }
                            
                            DrawerRow(title: "Biblioteca de Partituras", icon: "doc.text.fill", color: AppColors.primary) {
                                isSheetMusicPresented = true
                            }
                            
                            DrawerRow(title: "Clases Particulares & Maestros", icon: "graduationcap.fill", color: Color.blue) {
                                isClassesPresented = true
                            }
                            
                            DrawerRow(title: "Hub Musical: Mariachis & Grupos", icon: "music.mic.circle.fill", color: Color.orange) {
                                isMusicalHubPresented = true
                            }
                            
                            DrawerRow(title: "Explorar Música & Playlists", icon: "music.note.list", color: AppColors.musicPrimary) {
                                isExplorePresented = true
                            }
                            
                            DrawerRow(title: "Juegos Musicales & Oído", icon: "gamecontroller.fill", color: AppColors.gold) {
                                isGamesPresented = true
                            }
                            
                            DrawerRow(title: "Páginas de Artista & Bandas", icon: "person.3.sequence.fill", color: Color.teal) {
                                isPagesPresented = true
                            }
                            
                            DrawerRow(title: "Salas de Masterclass & Ensayos", icon: "video.fill", color: Color.indigo) {
                                isMeetingPresented = true
                            }
                        }
                        .padding(8)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        
                        // Economy, Wallet & Extras
                        VStack(spacing: 4) {
                            DrawerRow(title: "Monedero QAV & Recompensas", icon: "wallet.pass.fill", color: AppColors.chatPrimary) {
                                isWalletPresented = true
                            }
                            
                            DrawerRow(title: "Invitar Artistas ($0.50 USD)", icon: "gift.fill", color: AppColors.success) {
                                isInvitePresented = true
                            }
                            
                            DrawerRow(title: "Centro de Notificaciones", icon: "bell.fill", color: Color.pink) {
                                isNotificationsPresented = true
                            }
                            
                            DrawerRow(title: "Panel de Administración", icon: "shield.checkerboard", color: Color.gray) {
                                isAdminPresented = true
                            }
                        }
                        .padding(8)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        
                        // System Settings Group
                        VStack(spacing: 4) {
                            DrawerRow(title: "Configuración y Seguridad", icon: "gearshape.fill", color: theme.textSecondary) {
                                isSettingsPresented = true
                            }
                            
                            DrawerRow(title: "Tema: \(theme.currentTheme.title)", icon: "circle.lefthalf.filled", color: theme.textSecondary) {
                                isThemeDialogPresented = true
                            }
                            
                            DrawerRow(title: "Cerrar Sesión", icon: "arrow.right.square.fill", color: AppColors.errorRed) {
                                firebaseService.isAuthenticated = false
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                        .padding(8)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Menú PROVIWEB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isEventsPresented) { EventsHomeView() }
            .sheet(isPresented: $isSheetMusicPresented) { SheetMusicArchiveView() }
            .sheet(isPresented: $isClassesPresented) { SearchClassesView() }
            .sheet(isPresented: $isMusicalHubPresented) { MusicalHubView() }
            .sheet(isPresented: $isExplorePresented) { MusicExploreView() }
            .sheet(isPresented: $isGamesPresented) { MusicalGamesView() }
            .sheet(isPresented: $isPagesPresented) { ArtistPagesView() }
            .sheet(isPresented: $isMeetingPresented) { LiveMeetingRoomView() }
            .sheet(isPresented: $isWalletPresented) { QAVWalletView() }
            .sheet(isPresented: $isInvitePresented) { InviteEarnView() }
            .sheet(isPresented: $isNotificationsPresented) { NotificationsView() }
            .sheet(isPresented: $isSocialInsightsPresented) { SocialInsightsView() }
            .sheet(isPresented: $isSettingsPresented) { SettingsView() }
            .sheet(isPresented: $isAdminPresented) { AdminDashboardView() }
            .confirmationDialog("Selecciona el tema de PROVIWEB", isPresented: $isThemeDialogPresented) {
                Button("Oscuro (Night)") { theme.currentTheme = .night }
                Button("Atenuado (Dim)") { theme.currentTheme = .dim }
                Button("Claro (Light)") { theme.currentTheme = .light }
            }
        }
    }
}

// MARK: - Drawer Row Item
struct DrawerRow: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}
