import SwiftUI

// MARK: - Main Tab Bar Container View
public struct MainTabView: View {
    @State private var selectedTab: TabItem = .home
    @State private var isCreateModalPresented: Bool = false
    @State private var isAIProfessorPresented: Bool = false
    @State private var isPracticeStudioPresented: Bool = false
    @State private var isCreatePostPresented: Bool = false
    @State private var isWalletPresented: Bool = false
    @State private var isMarketplacePresented: Bool = false
    @State private var isEventsPresented: Bool = false
    @State private var isSheetMusicPresented: Bool = false
    @State private var isClassesPresented: Bool = false
    @State private var isQuotesPresented: Bool = false
    
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var chatVM = ChatViewModel()
    @ObservedObject private var callKit = CallKitService.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    public enum TabItem {
        case home
        case reels
        case chat
        case marketplace
        case profile
    }
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Active Tab Content
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .reels:
                    ReelsView()
                case .chat:
                    ChatListView()
                case .marketplace:
                    MarketplaceView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Mini-Player & Custom Bottom Bar
            VStack(spacing: 0) {
                // Persistent Floating Mini-Player
                MiniPlayerOverlay()
                    .padding(.bottom, 6)
                
                // Custom Bottom Navigation Bar
                HStack(spacing: 0) {
                    TabBarButton(title: "Inicio", icon: "house.fill", isSelected: selectedTab == .home) {
                        selectedTab = .home
                    }
                    
                    TabBarButton(title: "Reels", icon: "film.fill", isSelected: selectedTab == .reels) {
                        selectedTab = .reels
                    }
                    
                    // Central Create (+) Action Button
                    Button(action: {
                        isCreateModalPresented = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primaryGradient)
                                .frame(width: 50, height: 50)
                                .shadow(color: AppColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                            
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .offset(y: -8)
                    
                    // Messages Tab with Realtime Unread Badge
                    TabBarButton(title: "Mensajes", icon: "bubble.left.and.bubble.right.fill", isSelected: selectedTab == .chat, badgeCount: chatVM.totalUnreadCount) {
                        selectedTab = .chat
                    }
                    
                    TabBarButton(title: "Perfil", icon: "person.fill", isSelected: selectedTab == .profile) {
                        selectedTab = .profile
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .background(
                    theme.cardColor
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: -4)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
            
            // Incoming / Active VoIP Call Screen Overlay
            if callKit.isCallActive {
                ActiveCallOverlayView()
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }

            // Indicador de modo demostración (QA / revisión sin credenciales)
            if firebaseService.isDemoMode {
                VStack {
                    Text("Estás navegando en modo demostración")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.primary.opacity(0.85))
                        .cornerRadius(20)
                        .padding(.top, 6)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .zIndex(50)
            }
        }
        .sheet(isPresented: $isCreateModalPresented) {
            CreateModalSheet { option in
                switch option {
                case .post:
                    isCreatePostPresented = true
                case .reel:
                    selectedTab = .reels
                case .aiProfessor:
                    isAIProfessorPresented = true
                case .practice:
                    isPracticeStudioPresented = true
                case .event:
                    isEventsPresented = true
                case .sheetMusic:
                    isSheetMusicPresented = true
                case .classes:
                    isClassesPresented = true
                case .quotes:
                    isQuotesPresented = true
                case .music:
                    selectedTab = .home
                case .sell:
                    selectedTab = .marketplace
                case .wallet:
                    isWalletPresented = true
                case .invite:
                    isWalletPresented = true
                }
            }
        }
        .sheet(isPresented: $isAIProfessorPresented) {
            AIProfessorView()
        }
        .sheet(isPresented: $isPracticeStudioPresented) {
            PracticeStudioView()
        }
        .sheet(isPresented: $isCreatePostPresented) {
            CreatePostView()
        }
        .sheet(isPresented: $isEventsPresented) {
            EventsHomeView()
        }
        .sheet(isPresented: $isSheetMusicPresented) {
            SheetMusicArchiveView()
        }
        .sheet(isPresented: $isClassesPresented) {
            SearchClassesView()
        }
        .sheet(isPresented: $isQuotesPresented) {
            MusicalQuotesManagerView()
        }
        .sheet(isPresented: $isWalletPresented) {
            QAVWalletView()
        }
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var badgeCount: Int = 0
    let action: () -> Void
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? AppColors.primary : theme.textSecondary)
                    
                    if badgeCount > 0 {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -2)
                    }
                }
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? AppColors.primary : theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Active VoIP Video Call Overlay
struct ActiveCallOverlayView: View {
    @ObservedObject private var callKit = CallKitService.shared
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Remote Video Placeholder
                Spacer()
                
                AvatarView(urlString: callKit.callerAvatar, size: 90)
                    .padding(.bottom, 12)
                
                Text(callKit.callerName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(String(format: "%02d:%02d", callKit.callDurationSeconds / 60, callKit.callDurationSeconds % 60))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Call Controls
                HStack(spacing: 36) {
                    Button(action: { callKit.toggleMute() }) {
                        Image(systemName: callKit.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(18)
                            .background(Color.white.opacity(0.25))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { callKit.endCall() }) {
                        Image(systemName: "phone.down.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(22)
                            .background(AppColors.errorRed)
                            .clipShape(Circle())
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(18)
                            .background(Color.white.opacity(0.25))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }
}
