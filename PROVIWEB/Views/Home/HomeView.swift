import SwiftUI

// MARK: - Home Feed Main View
public struct HomeView: View {
    @StateObject private var viewModel = HomeFeedViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @State private var isAIProfessorPresented: Bool = false
    @State private var isPracticeStudioPresented: Bool = false
    @State private var isCreatePostPresented: Bool = false
    @State private var isMusicExplorePresented: Bool = false
    @State private var isWalletPresented: Bool = false
    @State private var isSideDrawerPresented: Bool = false
    @State private var isNotificationsPresented: Bool = false
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Top Custom App Bar
                        HStack(spacing: 12) {
                            // Side Drawer Menu Button
                            Button(action: {
                                isSideDrawerPresented = true
                            }) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.title2)
                                    .foregroundColor(theme.textPrimary)
                            }
                            
                            Text("PROVIWEB")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(AppColors.primary)
                            
                            Spacer()
                            
                            // Live Studio Button
                            Button(action: {
                                isPracticeStudioPresented = true
                            }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("En Vivo")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.85))
                                .cornerRadius(12)
                            }
                            
                            // AI Professor Shortcut
                            Button(action: {
                                isAIProfessorPresented = true
                            }) {
                                Image(systemName: "brain.head.profile")
                                    .font(.title3)
                                    .foregroundColor(AppColors.primary)
                                    .padding(6)
                                    .background(AppColors.primary.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            
                            // QAV Wallet Shortcut
                            Button(action: {
                                isWalletPresented = true
                            }) {
                                Image(systemName: "wallet.pass.fill")
                                    .font(.title3)
                                    .foregroundColor(AppColors.gold)
                            }
                            
                            // Notification Bell
                            Button(action: {
                                isNotificationsPresented = true
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.title3)
                                        .foregroundColor(theme.textPrimary)
                                    
                                    if viewModel.unreadNotificationsCount > 0 {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 9, height: 9)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // Stories / Live Practice Rooms Carousel
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                // Add Story / Live Studio Button
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(theme.cardColor)
                                            .frame(width: 64, height: 64)
                                            .overlay(Circle().stroke(AppColors.primary, lineWidth: 2))
                                        
                                        Image(systemName: "plus")
                                            .font(.title2)
                                            .foregroundColor(AppColors.primary)
                                    }
                                    
                                    Text("Tu Sala")
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                }
                                .onTapGesture {
                                    isPracticeStudioPresented = true
                                }
                                
                                ForEach(viewModel.liveSessions) { live in
                                    LiveRoomItem(session: live) {
                                        isPracticeStudioPresented = true
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Quick Post Composer Card
                        HStack(spacing: 12) {
                            AvatarView(urlString: FirebaseService.shared.currentUser?.image, size: 38, isVerified: true)
                            
                            Text("¿Qué estás practicando hoy? Comparte un video o audio...")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                            
                            Spacer()
                            
                            Image(systemName: "square.and.pencil")
                                .foregroundColor(AppColors.primary)
                        }
                        .padding(12)
                        .background(theme.cardColor)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .onTapGesture {
                            isCreatePostPresented = true
                        }
                        
                        // Verified Entities Carousel
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Entidades y Orquestas Verificadas")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 16)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.verifiedEntities) { entity in
                                        VerifiedEntityCard(entity: entity)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // Feed Content Tabs
                        HStack(spacing: 16) {
                            ForEach(HomeFeedViewModel.FeedTab.allCases) { tab in
                                Button(action: {
                                    viewModel.selectedTab = tab
                                }) {
                                    Text(tab.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(viewModel.selectedTab == tab ? .bold : .medium)
                                        .foregroundColor(viewModel.selectedTab == tab ? AppColors.primary : theme.textSecondary)
                                        .padding(.bottom, 6)
                                        .overlay(
                                            Rectangle()
                                                .fill(viewModel.selectedTab == tab ? AppColors.primary : Color.clear)
                                                .frame(height: 2.5),
                                            alignment: .bottom
                                        )
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // Feed Content
                        if viewModel.selectedTab == .posts {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.posts) { post in
                                    PostCardView(
                                        post: post,
                                        onLike: { viewModel.toggleLike(for: post) }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        } else if viewModel.selectedTab == .music {
                            VStack(spacing: 12) {
                                ForEach(viewModel.featuredSongs) { song in
                                    SongFeedRow(song: song)
                                }
                            }
                            .padding(.horizontal, 16)
                        } else if viewModel.selectedTab == .books {
                            VStack(spacing: 12) {
                                ForEach(viewModel.recentBooks) { book in
                                    BookFeedRow(book: book)
                                }
                            }
                            .padding(.horizontal, 16)
                        } else {
                            JobBoardPlaceholder()
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 80)
                }
                .refreshable {
                    await viewModel.refreshFeed()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isAIProfessorPresented) {
                AIProfessorView()
            }
            .sheet(isPresented: $isPracticeStudioPresented) {
                PracticeStudioView()
            }
            .sheet(isPresented: $isCreatePostPresented) {
                CreatePostView()
            }
            .sheet(isPresented: $isWalletPresented) {
                QAVWalletView()
            }
            .sheet(isPresented: $isSideDrawerPresented) {
                SideDrawerView()
            }
            .sheet(isPresented: $isNotificationsPresented) {
                NotificationsView()
            }
        }
    }
}

// MARK: - Live Room Item
struct LiveRoomItem: View {
    let session: LiveSessionModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottom) {
                    AvatarView(urlString: session.hostDp, size: 64)
                        .overlay(Circle().stroke(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5))
                    
                    Text("LIVE")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(6)
                        .offset(y: 4)
                }
                
                Text(session.hostName)
                    .font(.caption2)
                    .foregroundColor(ThemeManager.shared.textPrimary)
                    .lineLimit(1)
                    .frame(width: 68)
            }
        }
    }
}

// MARK: - Verified Entity Card
struct VerifiedEntityCard: View {
    let entity: UserModel
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 10) {
            AvatarView(urlString: entity.image, size: 40, isVerified: true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                
                Text(entity.location ?? "Institución")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Song Feed Row
struct SongFeedRow: View {
    let song: SongModel
    @ObservedObject private var theme = ThemeManager.shared
    private let player = AudioPlayerService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                player.playSong(song)
            }) {
                ZStack {
                    if let cover = song.coverUrl, let url = URL(string: cover) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(AppColors.musicPrimary.opacity(0.3))
                        }
                        .frame(width: 50, height: 50)
                        .cornerRadius(10)
                    }
                    
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                
                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            Text(song.genre ?? "Clásica")
                .font(.caption2)
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.primary.opacity(0.12))
                .cornerRadius(8)
        }
        .padding(12)
        .background(theme.cardColor)
        .cornerRadius(16)
    }
}

// MARK: - Book Feed Row
struct BookFeedRow: View {
    let book: BookModel
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.title)
                .foregroundColor(AppColors.gold)
                .padding(10)
                .background(AppColors.gold.opacity(0.15))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                
                Text(book.author)
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundColor(AppColors.primary)
            }
        }
        .padding(12)
        .background(theme.cardColor)
        .cornerRadius(16)
    }
}

// MARK: - Job Board Placeholder
struct JobBoardPlaceholder: View {
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 40))
                .foregroundColor(AppColors.primary)
            
            Text("Bolsa de Empleo Musical PROVIWEB")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
            
            Text("Encuentra audiciones para orquestas, plazas docentes y solicitudes de agrupaciones.")
                .font(.caption)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(theme.cardColor)
        .cornerRadius(16)
    }
}
