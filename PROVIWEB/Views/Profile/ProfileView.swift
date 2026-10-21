import SwiftUI

// MARK: - User Profile & Verification View
public struct ProfileView: View {
    @ObservedObject private var firebaseService = FirebaseService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var selectedTab: Int = 0
    @State private var isVerificationSheetPresented: Bool = false
    @State private var isThemeSelectorPresented: Bool = false
    @State private var isSettingsPresented: Bool = false
    @State private var isSocialInsightsPresented: Bool = false
    @State private var socialInsightsTab: SocialInsightsView.InsightTab = .followers
    @State private var isAchievementsPresented: Bool = false
    
    public init() {}
    
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
                            
                            // Stats Row (Clickable to open Social Insights)
                            HStack(spacing: 32) {
                                StatItem(count: "128", title: "Posts")
                                
                                Button(action: {
                                    socialInsightsTab = .followers
                                    isSocialInsightsPresented = true
                                }) {
                                    StatItem(count: "3.4k", title: "Seguidores")
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    socialInsightsTab = .following
                                    isSocialInsightsPresented = true
                                }) {
                                    StatItem(count: "290", title: "Siguiendo")
                                }
                                .buttonStyle(PlainButtonStyle())
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
                                    isAchievementsPresented = true
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trophy.fill")
                                        Text("Logros")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.gold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(AppColors.gold.opacity(0.15))
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
                                Text("Nivel de Práctica: Maestro")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textPrimary)
                                Text("Más de 120 horas acumuladas este mes")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isSettingsPresented = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(theme.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
            .sheet(isPresented: $isSocialInsightsPresented) {
                SocialInsightsView(initialTab: socialInsightsTab)
            }
            .sheet(isPresented: $isVerificationSheetPresented) {
                VerificationRequestView()
            }
            .sheet(isPresented: $isAchievementsPresented) {
                AchievementsView()
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
