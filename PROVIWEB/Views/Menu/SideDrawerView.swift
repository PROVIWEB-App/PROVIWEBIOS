import SwiftUI

// MARK: - Full Side Navigation Drawer Menu
public struct SideDrawerView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isExplorePresented: Bool = false
    @State private var isAdminPresented: Bool = false
    @State private var isPagesPresented: Bool = false
    @State private var isGamesPresented: Bool = false
    @State private var isMeetingPresented: Bool = false
    @State private var isInvitePresented: Bool = false
    @State private var isWalletPresented: Bool = false
    @State private var isNotificationsPresented: Bool = false
    @State private var isThemeDialogPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // User Profile Summary Header
                        HStack(spacing: 14) {
                            AvatarView(urlString: firebaseService.currentUser?.image, size: 56, isVerified: true)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(firebaseService.currentUser?.name ?? "Israel Violín")
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                
                                Text("@\(firebaseService.currentUser?.username ?? "israviolink")")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                
                                Text("Saldo: \(String(format: "$%.2f USD", firebaseService.walletBalance.balanceUSD))")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Menu Categories
                        VStack(spacing: 4) {
                            DrawerRow(title: "Explorar Música & Playlists", icon: "music.note.list", color: AppColors.musicPrimary) {
                                isExplorePresented = true
                            }
                            
                            DrawerRow(title: "Juegos Musicales & Oído", icon: "gamecontroller.fill", color: AppColors.gold) {
                                isGamesPresented = true
                            }
                            
                            DrawerRow(title: "Páginas de Artista & Grupos", icon: "music.mic.circle.fill", color: Color.orange) {
                                isPagesPresented = true
                            }
                            
                            DrawerRow(title: "Salas de Masterclass & Ensayos", icon: "video.fill", color: Color.purple) {
                                isMeetingPresented = true
                            }
                            
                            DrawerRow(title: "Monedero QAV & Recompensas", icon: "wallet.pass.fill", color: AppColors.chatPrimary) {
                                isWalletPresented = true
                            }
                            
                            DrawerRow(title: "Invitar Artistas ($0.50 USD)", icon: "gift.fill", color: AppColors.success) {
                                isInvitePresented = true
                            }
                            
                            DrawerRow(title: "Centro de Notificaciones", icon: "bell.fill", color: Color.pink) {
                                isNotificationsPresented = true
                            }
                            
                            DrawerRow(title: "Panel de Administración", icon: "shield.checkerboard", color: Color.indigo) {
                                isAdminPresented = true
                            }
                        }
                        .padding(8)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        
                        // System Settings Group
                        VStack(spacing: 4) {
                            DrawerRow(title: "Tema: \(theme.currentTheme.title)", icon: "circle.lefthalf.filled", color: theme.textSecondary) {
                                isThemeDialogPresented = true
                            }
                            
                            DrawerRow(title: "Idioma: Español", icon: "globe", color: theme.textSecondary) {}
                            
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
            .sheet(isPresented: $isExplorePresented) { MusicExploreView() }
            .sheet(isPresented: $isAdminPresented) { AdminDashboardView() }
            .sheet(isPresented: $isPagesPresented) { ArtistPagesView() }
            .sheet(isPresented: $isGamesPresented) { MusicalGamesView() }
            .sheet(isPresented: $isMeetingPresented) { LiveMeetingRoomView() }
            .sheet(isPresented: $isInvitePresented) { InviteEarnView() }
            .sheet(isPresented: $isWalletPresented) { QAVWalletView() }
            .sheet(isPresented: $isNotificationsPresented) { NotificationsView() }
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
