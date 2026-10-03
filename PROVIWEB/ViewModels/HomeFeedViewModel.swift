import Foundation
import SwiftUI
import Combine

// MARK: - Home Feed ViewModel
@MainActor
public class HomeFeedViewModel: ObservableObject {
    @Published public var posts: [PostModel] = []
    @Published public var liveSessions: [LiveSessionModel] = []
    @Published public var verifiedEntities: [UserModel] = []
    @Published public var recentBooks: [BookModel] = []
    @Published public var featuredSongs: [SongModel] = []
    @Published public var isLoading: Bool = false
    @Published public var selectedTab: FeedTab = .posts
    @Published public var unreadNotificationsCount: Int = 3
    @Published public var uploadProgress: Double? = nil
    @Published public var uploadStatusText: String? = nil
    
    public enum FeedTab: String, CaseIterable, Identifiable {
        case posts = "Publicaciones"
        case music = "Música"
        case books = "Partituras"
        case jobs = "Empleos"
        
        public var id: String { rawValue }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let firebaseService = FirebaseService.shared
    
    public init() {
        setupBindings()
    }
    
    private func setupBindings() {
        firebaseService.$posts
            .assign(to: &$posts)
        firebaseService.$liveSessions
            .assign(to: &$liveSessions)
        firebaseService.$verifiedEntities
            .assign(to: &$verifiedEntities)
        firebaseService.$books
            .assign(to: &$recentBooks)
        firebaseService.$songs
            .assign(to: &$featuredSongs)
    }
    
    public func refreshFeed() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        isLoading = false
    }
    
    public func toggleLike(for post: PostModel) {
        firebaseService.toggleLikePost(postId: post.id)
    }
}

// MARK: - Reels ViewModel
@MainActor
public class ReelsViewModel: ObservableObject {
    @Published public var reels: [ReelModel] = []
    @Published public var currentReelIndex: Int = 0
    @Published public var isCommentsSheetPresented: Bool = false
    @Published public var isShareSheetPresented: Bool = false
    
    private let firebaseService = FirebaseService.shared
    
    public init() {
        firebaseService.$reels
            .assign(to: &$reels)
    }
    
    public func toggleLike(at index: Int) {
        guard index >= 0 && index < reels.count else { return }
        var reel = reels[index]
        let isLiked = reel.isLiked ?? false
        reel.isLiked = !isLiked
        reel.likesCount = isLiked ? max(0, (reel.likesCount ?? 0) - 1) : (reel.likesCount ?? 0) + 1
        reels[index] = reel
    }
}
