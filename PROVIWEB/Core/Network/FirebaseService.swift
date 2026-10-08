import Foundation
import Combine
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

// MARK: - Firebase Service Wrapper & Mock/Live Realtime Database Handler
@MainActor
public class FirebaseService: ObservableObject {
    public static let shared = FirebaseService()
    
    @Published public var currentUserId: String = "user_demo_violin_001"
    @Published public var isAuthenticated: Bool = true
    @Published public var currentUser: UserModel? = UserModel(
        id: "user_demo_violin_001",
        uid: "user_demo_violin_001",
        name: "Israel Violín Maestro",
        email: "israel@proviweb.com",
        username: "israviolink",
        image: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
        bio: "Violinista profesional & Fundador de PROVIWEB. Compartiendo el arte de la música clásica y el mariachi 🎻🎶",
        phone: "+52 55 1234 5678",
        location: "Ciudad de México",
        verified: "musician",
        onlineStatus: "Online",
        instrument: "Violín",
        experienceYears: 15,
        referralCode: "ISRA2026"
    )
    
    // In-memory synced database nodes mirroring Firebase Realtime Database
    @Published public var posts: [PostModel] = []
    @Published public var reels: [ReelModel] = []
    @Published public var songs: [SongModel] = []
    @Published public var playlists: [PlaylistModel] = []
    @Published public var books: [BookModel] = []
    @Published public var verifiedEntities: [UserModel] = []
    @Published public var liveSessions: [LiveSessionModel] = []
    @Published public var walletBalance: WalletBalanceModel = WalletBalanceModel(
        balanceUSD: 145.50,
        diamonds: 820,
        referralCount: 14,
        walletAddress: "0x71C...4982aF"
    )
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        loadInitialMockData()
    }
    
    public func addPracticeReward() {
        walletBalance.balanceUSD += 1.00
        walletBalance.diamonds += 5
    }
    
    public func toggleLikePost(postId: String) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var post = posts[index]
            let isLiked = post.likedByCurrentUser ?? false
            post.likedByCurrentUser = !isLiked
            let currentLikes = Int(post.pLikes ?? "0") ?? 0
            post.pLikes = "\(isLiked ? max(0, currentLikes - 1) : currentLikes + 1)"
            posts[index] = post
        }
    }
    
    public func addComment(postId: String, text: String) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var post = posts[index]
            let currentComments = Int(post.pComments ?? "0") ?? 0
            post.pComments = "\(currentComments + 1)"
            posts[index] = post
        }
    }
    
    public func createPost(title: String, description: String, feeling: String?, image: String?, video: String?, audio: String?) {
        guard let user = currentUser else { return }
        let newPost = PostModel(
            id: UUID().uuidString,
            uid: user.id,
            uName: user.name,
            uEmail: user.email,
            uDp: user.image,
            pTitle: title,
            pDescr: description,
            pImage: image,
            pVideo: video,
            pAudio: audio,
            pTime: "\(Date().timeIntervalSince1970 * 1000)",
            pLikes: "0",
            pComments: "0",
            pShare: "0",
            feeling: feeling,
            location: user.location,
            isPromoted: false
        )
        posts.insert(newPost, at: 0)
    }
    
    private func loadInitialMockData() {
        // Mock Posts
        posts = [
            PostModel(
                id: "post_1",
                uid: "user_demo_violin_001",
                uName: "Israel Violín Maestro",
                uDp: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
                pTitle: "Práctica del Concierto de Mendelssohn en Mi Menor",
                pDescr: "Trabajando en el fraseo del primer movimiento y la afinación de las octavas. ¿Qué les parece el sonido de este violín artesanal? 🎻✨",
                pImage: "https://images.unsplash.com/photo-1612225330812-01a9c6b355ec?w=800&auto=format&fit=crop&q=60",
                pAudio: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
                pTime: "1725000000000",
                pLikes: "148",
                pComments: "24",
                pShare: "8",
                feeling: "Inspirado",
                location: "Sala Nezahualcóyotl"
            ),
            PostModel(
                id: "post_2",
                uid: "entity_mariachi_01",
                uName: "Mariachi Sinfónico Real",
                uDp: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
                pTitle: "¡Disponible para eventos y serenatas este fin de semana!",
                pDescr: "Contamos con repertorio clásico y tradicional mexicano. Solicita tu cotización directamente desde la app en el botón de Cotizar 🎺🎻🇲🇽",
                pImage: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=800&auto=format&fit=crop&q=60",
                pTime: "1724980000000",
                pLikes: "312",
                pComments: "45",
                pShare: "32",
                feeling: "Feliz",
                location: "Guadalajara, Jalisco"
            )
        ]
        
        // Mock Reels
        reels = [
            ReelModel(
                id: "reel_1",
                videoUri: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                caption: "Técnica de Spiccato a tempo 140 BPM 🔥 #ViolinMastery #Spiccato #Proviweb",
                soundTitle: "Sonata No. 1 en Sol Menor - J.S. Bach",
                soundAuthor: "Israel Violín",
                authorId: "user_demo_violin_001",
                authorName: "Israel Violín",
                authorDp: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
                likesCount: 1420,
                commentsCount: 89
            ),
            ReelModel(
                id: "reel_2",
                videoUri: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyBlazes.mp4",
                caption: "Dueto de Mariachi en vivo en Bellas Artes 🎻🎺 #Mariachi #EnVivo",
                soundTitle: "El Son de la Negra (En Vivo)",
                soundAuthor: "Mariachi Sinfónico Real",
                authorId: "entity_mariachi_01",
                authorName: "Mariachi Real",
                authorDp: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
                likesCount: 3890,
                commentsCount: 230
            )
        ]
        
        // Mock Songs
        songs = [
            SongModel(
                id: "song_1",
                title: "Czardas de Vittorio Monti",
                artist: "Israel Violín",
                audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
                coverUrl: "https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=60",
                genre: "Clásica",
                duration: 215,
                plays: 18450
            ),
            SongModel(
                id: "song_2",
                title: "Huapango de Moncayo (Arreglo Violín Solo)",
                artist: "Orquesta de Cuerdas Proviweb",
                audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
                coverUrl: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&auto=format&fit=crop&q=60",
                genre: "Sinfónica",
                duration: 380,
                plays: 32900
            )
        ]
        
        // Mock Books
        books = [
            BookModel(
                id: "book_1",
                title: "Suzuki Violin School - Vol. 1",
                author: "Shinichi Suzuki",
                category: "Método Suzuki",
                coverUrl: "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=500&auto=format&fit=crop&q=60"
            ),
            BookModel(
                id: "book_2",
                title: "Kreutzer 42 Estudios o Caprichos para Violín",
                author: "Rodolphe Kreutzer",
                category: "Estudios Técnicos",
                coverUrl: "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=500&auto=format&fit=crop&q=60"
            )
        ]
        
        // Mock Verified Entities
        verifiedEntities = [
            UserModel(
                id: "entity_1",
                name: "Conservatorio Nacional de Música",
                image: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
                location: "CDMX",
                verified: "entity"
            ),
            UserModel(
                id: "entity_2",
                name: "Orquesta Filarmónica de Cámara",
                image: "https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=60",
                location: "Monterrey",
                verified: "entity"
            ),
            UserModel(
                id: "entity_3",
                name: "Academia de Violín Suzuki",
                image: "https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&auto=format&fit=crop&q=60",
                location: "Bogotá",
                verified: "entity"
            )
        ]
        
        // Mock Live Sessions
        liveSessions = [
            LiveSessionModel(
                id: "live_1",
                hostId: "user_demo_violin_001",
                hostName: "Israel Violín",
                hostDp: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=60",
                title: "Masterclass: Golpes de Arco y Afinación",
                mode: .practice,
                listenersCount: 42
            ),
            LiveSessionModel(
                id: "live_2",
                hostId: "host_podcast_01",
                hostName: "Podcast: Hablemos de Música",
                hostDp: "https://images.unsplash.com/photo-1590602847861-f357a9332bbc?w=500&auto=format&fit=crop&q=60",
                title: "Episodio 18: La vida del músico profesional",
                mode: .podcast,
                listenersCount: 128
            )
        ]
    }
    
    // MARK: - Live Firebase Realtime Database & Auth Integration
    public func startLiveDatabaseSync() {
        #if canImport(FirebaseDatabase)
        let rootRef = Database.database().reference()
        
        // 1. Sync Posts in Realtime
        rootRef.child("Posts").queryLimited(toLast: 50).observe(.value) { [weak self] snapshot in
            guard let self = self, let value = snapshot.value as? [String: [String: Any]] else { return }
            var remotePosts: [PostModel] = []
            for (key, dict) in value {
                let post = PostModel(
                    id: key,
                    uid: dict["uid"] as? String ?? "",
                    uName: dict["uName"] as? String,
                    uEmail: dict["uEmail"] as? String,
                    uDp: dict["uDp"] as? String,
                    pTitle: dict["pTitle"] as? String,
                    pDescr: dict["pDescr"] as? String,
                    pImage: dict["pImage"] as? String,
                    pVideo: dict["pVideo"] as? String,
                    pAudio: dict["pAudio"] as? String,
                    pTime: dict["pTime"] as? String,
                    pLikes: dict["pLikes"] as? String ?? "0",
                    pComments: dict["pComments"] as? String ?? "0",
                    pShare: dict["pShare"] as? String ?? "0",
                    feeling: dict["feeling"] as? String,
                    location: dict["location"] as? String,
                    isPromoted: dict["isPromoted"] as? Bool ?? false
                )
                remotePosts.append(post)
            }
            if !remotePosts.isEmpty {
                self.posts = remotePosts.sorted { ($0.pTime ?? "") > ($1.pTime ?? "") }
            }
        }
        
        // 2. Sync Current User Data
        if let user = currentUser {
            rootRef.child("Users").child(user.id).observe(.value) { [weak self] snapshot in
                guard let self = self, let dict = snapshot.value as? [String: Any] else { return }
                self.currentUser = UserModel(
                    id: user.id,
                    uid: user.id,
                    name: dict["name"] as? String ?? user.name,
                    email: dict["email"] as? String ?? user.email,
                    username: dict["username"] as? String ?? user.username,
                    image: dict["image"] as? String ?? user.image,
                    cover: dict["cover"] as? String,
                    bio: dict["bio"] as? String ?? user.bio,
                    phone: dict["phone"] as? String ?? user.phone,
                    location: dict["location"] as? String ?? user.location,
                    verified: dict["verified"] as? String ?? user.verified,
                    onlineStatus: dict["onlineStatus"] as? String ?? "Online",
                    instrument: dict["instrument"] as? String ?? user.instrument,
                    experienceYears: dict["experienceYears"] as? Int ?? user.experienceYears,
                    referralCode: dict["referralCode"] as? String ?? user.referralCode
                )
            }
        }
        #endif
    }
    
    public func publishPostToCloud(post: PostModel) {
        #if canImport(FirebaseDatabase)
        let rootRef = Database.database().reference()
        let postDict: [String: Any] = [
            "uid": post.uid ?? "",
            "uName": post.uName ?? "",
            "uEmail": post.uEmail ?? "",
            "uDp": post.uDp ?? "",
            "pTitle": post.pTitle ?? "",
            "pDescr": post.pDescr ?? "",
            "pImage": post.pImage ?? "",
            "pVideo": post.pVideo ?? "",
            "pAudio": post.pAudio ?? "",
            "pTime": post.pTime ?? "\(Date().timeIntervalSince1970 * 1000)",
            "pLikes": post.pLikes ?? "0",
            "pComments": post.pComments ?? "0",
            "pShare": post.pShare ?? "0",
            "feeling": post.feeling ?? "",
            "location": post.location ?? ""
        ]
        rootRef.child("Posts").child(post.id).setValue(postDict)
        #endif
    }
}
