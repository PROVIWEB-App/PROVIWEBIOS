import Foundation
import SwiftUI
import Combine
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Ad Post Model (nodo RTDB `AdsPost`, esquema idéntico a Android)
//
// Réplica de ModelAdsPost.java / CreateAdsActivity.java:2320-2408 / HomeFragment.java:1743-1815:
//   AdsPost/{key = String(millis)} = { id(uid anunciante), pId, text, pViews, type, expiry, video, image, pTime }
// CADA campo es String en Android; el parseo es tolerante a ausencias o tipos no String.
public struct AdPostModel: Identifiable {
    /// Key del nodo RTDB = `String(millis)` (timestamp, NO push key). NO confundir con el uid.
    public let id: String
    /// Campo `id` del esquema: uid del anunciante.
    public var advertiserId: String
    public var pId: String
    public var text: String
    public var pViews: String
    /// "text" | "image" | "video" | "post"
    public var type: String
    /// String: días si ≤6 dígitos, epoch ms si no (HomeFragment.java:1783-1795).
    public var expiry: String
    /// "no" | URL
    public var video: String
    /// "no" | URL
    public var image: String
    /// Epoch ms como String.
    public var pTime: String

    public init(id: String, dict: [String: Any]) {
        self.id = id
        self.advertiserId = AdPostModel.stringValue(dict["id"]) ?? ""
        self.pId = AdPostModel.stringValue(dict["pId"]) ?? id
        self.text = AdPostModel.stringValue(dict["text"]) ?? ""
        self.pViews = AdPostModel.stringValue(dict["pViews"]) ?? "0"
        self.type = AdPostModel.stringValue(dict["type"]) ?? "text"
        self.expiry = AdPostModel.stringValue(dict["expiry"]) ?? ""
        self.video = AdPostModel.stringValue(dict["video"]) ?? "no"
        self.image = AdPostModel.stringValue(dict["image"]) ?? "no"
        self.pTime = AdPostModel.stringValue(dict["pTime"]) ?? "0"
    }

    public init(id: String, advertiserId: String, pId: String, text: String, pViews: String, type: String, expiry: String, video: String, image: String, pTime: String) {
        self.id = id
        self.advertiserId = advertiserId
        self.pId = pId
        self.text = text
        self.pViews = pViews
        self.type = type
        self.expiry = expiry
        self.video = video
        self.image = image
        self.pTime = pTime
    }

    public var pTimeMillis: Int64 {
        Int64(pTime.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    /// Réplica de HomeFragment.java:1782-1795: días si `expiry` ≤6 dígitos (`pTime + días*86400000`), epoch si no.
    public var effectiveExpiryMillis: Int64 {
        let trimmed = expiry.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return 0 }
        if trimmed.count > 6 {
            return Int64(trimmed) ?? 0
        }
        guard let days = Int64(trimmed) else { return 0 }
        let base = pTimeMillis > 0 ? pTimeMillis : Int64(Date().timeIntervalSince1970 * 1000)
        return base + days * 86_400_000
    }

    /// `true` si el anuncio ha caducado (HomeFragment.java:1798-1802 descarta caducados).
    public func isExpired(nowMillis: Int64) -> Bool {
        let expiryMillis = effectiveExpiryMillis
        return expiryMillis != 0 && expiryMillis <= nowMillis
    }

    /// URL de la imagen, o `nil` cuando el campo vale "no" / vacío.
    public var imageURL: URL? {
        let trimmed = image.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("no") else { return nil }
        return URL(string: trimmed)
    }

    /// URL del video, o `nil` cuando el campo vale "no" / vacío.
    public var videoURL: URL? {
        let trimmed = video.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !trimmed.lowercased().hasPrefix("no") else { return nil }
        return URL(string: trimmed)
    }

    private static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String { return value }
        if raw is NSNull { return nil }
        if let value = raw { return String(describing: value) }
        return nil
    }
}

// MARK: - Feed Item (post normal o anuncio pagado intercalado)
public enum FeedItem: Identifiable {
    case post(PostModel)
    case ad(AdPostModel)

    public var id: String {
        switch self {
        case .post(let post): return "post-\(post.id)"
        case .ad(let ad): return "ad-\(ad.id)"
        }
    }
}

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
    /// Anuncios pagados activos del nodo RTDB `AdsPost` (en demo: lista vacía).
    @Published public var ads: [AdPostModel] = []
    /// Interruptor `Ads/type` ("on"|"off", solo lectura, gestionado desde consola).
    @Published public var adsSwitchOn: Bool = true
    /// Posts + anuncios intercalados con la cadencia de Android (posición 0 + cada 4 posts).
    @Published public var feedItems: [FeedItem] = []
    
    public enum FeedTab: String, CaseIterable, Identifiable {
        case posts = "Publicaciones"
        case music = "Música"
        case books = "Partituras"
        case jobs = "Empleos"
        
        public var id: String { rawValue }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let firebaseService = FirebaseService.shared
    private var areAdsStarted = false
    /// Máx. 1 incremento de `pViews` por anuncio por sesión (réplica AdapterAdsPost.java:137-143).
    private var countedAdImpressions = Set<String>()
    #if canImport(FirebaseDatabase)
    private var adsObserver: (handle: DatabaseHandle, remove: () -> Void)?
    private var adsSwitchObserver: (handle: DatabaseHandle, remove: () -> Void)?
    #endif
    
    public init() {
        setupBindings()
        ensureAdsStarted()
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
        // Reconstruye la lista intercalada cuando cambian los posts.
        firebaseService.$posts
            .sink { [weak self] latestPosts in
                self?.rebuildFeedItems(posts: latestPosts)
            }
            .store(in: &cancellables)
    }

    // MARK: - Observador de AdsPost (HomeFragment.java:1743-1815)
    /// Arranca la escucha de `AdsPost` + `Ads/type`. Sin sesión real (demo) deja la lista de ads vacía.
    public func ensureAdsStarted() {
        guard !areAdsStarted else { return }
        guard FirebaseService.shared.canWriteToCloud else {
            // Modo demo (sin sesión): lista vacía de anuncios; no se rompe el seed actual del feed.
            ads = []
            rebuildFeedItems()
            return
        }
        areAdsStarted = true
        #if canImport(FirebaseDatabase)
        observeAdsPost()
        observeAdsSwitch()
        #else
        ads = []
        rebuildFeedItems()
        #endif
    }

    #if canImport(FirebaseDatabase)
    private func observeAdsPost() {
        let ref = Database.database().reference().child("AdsPost")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                var rows: [AdPostModel] = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    rows.append(AdPostModel(id: snap.key, dict: dict))
                }
                // HomeFragment.java:1798-1802: descarta caducados.
                let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
                var rows2 = rows.filter { !$0.isExpired(nowMillis: nowMillis) }
                // HomeFragment.java:2026: shuffle de los promocionados, pero UNA sola vez por
                // llegada de datos (no en cada rebuild) para no saltar el feed al refrescar posts.
                rows2.shuffle()
                self.ads = rows2
                self.rebuildFeedItems()
            }
        }
        adsObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }

    /// Interruptor `Ads/type` = "on"|"off" (solo lectura en Android; si es "off" no se insertan AdsPost en el feed).
    private func observeAdsSwitch() {
        let ref = Database.database().reference().child("Ads").child("type")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self else { return }
                let raw: String
                if let value = snapshot.value as? String {
                    raw = value
                } else if let value = snapshot.value {
                    raw = String(describing: value)
                } else {
                    raw = "on"
                }
                self.adsSwitchOn = raw.lowercased() != "off"
                self.rebuildFeedItems()
            }
        }
        adsSwitchObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }
    #endif

    // MARK: - Intercalado posts + anuncios (HomeFragment.java:2057-2081 `interleavePosts`)
    /// Réplica exacta de la cadencia de Android: 1 anuncio en la posición 0 y luego
    /// 1 anuncio cada 4 posts; los anuncios sobrantes van al final.
    public static func interleave(posts: [PostModel], ads: [AdPostModel]) -> [FeedItem] {
        if ads.isEmpty { return posts.map { .post($0) } }
        if posts.isEmpty { return ads.map { .ad($0) } }

        var result: [FeedItem] = []
        result.append(.ad(ads[0])) // 1er anuncio arriba del todo
        var adIndex = 1
        for (i, post) in posts.enumerated() {
            result.append(.post(post))
            if (i + 1) % 4 == 0 && adIndex < ads.count {
                result.append(.ad(ads[adIndex]))
                adIndex += 1
            }
        }
        while adIndex < ads.count {
            result.append(.ad(ads[adIndex]))
            adIndex += 1
        }
        return result
    }

    public func rebuildFeedItems(posts latestPosts: [PostModel]? = nil) {
        let sourcePosts = (latestPosts ?? posts).sorted {
            (Int64($0.pTime ?? "") ?? 0) > (Int64($1.pTime ?? "") ?? 0)
        }
        var activeAds = ads
        if !adsSwitchOn {
            // El interruptor `Ads/type == "off"` (gestionado desde consola) oculta los anuncios.
            activeAds = []
        }
        // El orden ya viene barajado desde el observer (shuffle por llegada de datos).
        feedItems = HomeFeedViewModel.interleave(posts: sourcePosts, ads: activeAds)
    }

    // MARK: - Métrica de impresiones (AdapterAdsPost.java:137-143)
    /// Incrementa `pViews` con lectura+1 (sin transacción), máx. 1 vez por anuncio por sesión.
    public func registerAdImpression(_ ad: AdPostModel) {
        guard !countedAdImpressions.contains(ad.id) else { return }
        countedAdImpressions.insert(ad.id)
        guard FirebaseService.shared.canWriteToCloud else { return }
        #if canImport(FirebaseDatabase)
        let views = (Int(ad.pViews) ?? 0) + 1
        let ref = Database.database().reference().child("AdsPost").child(ad.id)
        ref.updateChildValues(["pViews": String(views)])
        #endif
    }
    
    public func refreshFeed() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 800_000_000)
        rebuildFeedItems()
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
