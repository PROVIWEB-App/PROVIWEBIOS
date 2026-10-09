import SwiftUI

// MARK: - Social Insights: Followers, Following, Likes & Profile Visitors View
public struct SocialInsightsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public enum InsightTab: String, CaseIterable {
        case followers = "Seguidores"
        case following = "Seguidos"
        case likedPosts = "Posts Guardados"
        case likedReels = "Reels Favoritos"
        case likedTeachers = "Maestros"
        case profileViewers = "Visitas"
    }
    
    @State public var selectedTab: InsightTab
    
    public init(initialTab: InsightTab = .followers) {
        _selectedTab = State(initialValue: initialTab)
    }
    
    // Sample Users
    @State private var sampleUsers: [UserModel] = [
        UserModel(
            id: "u1",
            name: "Elena Morales",
            username: "elenaviolin",
            image: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
            bio: "Violinista en Filarmónica de la Ciudad de México.",
            verified: "musician",
            instrument: "Violín"
        ),
        UserModel(
            id: "u2",
            name: "Mariachi Sol de Oro",
            username: "soldeoro",
            image: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
            bio: "Mariachi profesional disponible para eventos y serenatas.",
            verified: "entity",
            instrument: "Mariachi"
        ),
        UserModel(
            id: "u3",
            name: "Mateo Fernández",
            username: "mateocello",
            image: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=60",
            bio: "Violonchelista y compositor.",
            verified: "musician",
            instrument: "Violonchelo"
        )
    ]
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Filter Bar
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(InsightTab.allCases, id: \.self) { tab in
                                Button(action: { selectedTab = tab }) {
                                    Text(tab.rawValue)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(selectedTab == tab ? .white : theme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedTab == tab ? AppColors.primary : theme.cardColor)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    
                    // Tab Content
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(sampleUsers) { user in
                                SocialUserRowItem(user: user, currentTab: selectedTab)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Comunidad & Actividad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// MARK: - Social User Row Item
struct SocialUserRowItem: View {
    let user: UserModel
    let currentTab: SocialInsightsView.InsightTab
    @ObservedObject private var theme = ThemeManager.shared
    @State private var isFollowing: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(urlString: user.image, size: 48, isVerified: user.verified != nil)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
                
                Text("@\(user.username)")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if currentTab == .profileViewers {
                Text("Visto hoy")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            } else {
                Button(action: { isFollowing.toggle() }) {
                    Text(isFollowing ? "Siguiendo" : "Seguir")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isFollowing ? theme.textPrimary : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(isFollowing ? theme.cardColor : AppColors.primary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isFollowing ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                }
            }
        }
        .padding(12)
        .background(theme.cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}
