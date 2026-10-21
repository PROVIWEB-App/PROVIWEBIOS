import Foundation
import SwiftUI
#if canImport(FirebaseDatabase)
import FirebaseDatabase
#endif

// MARK: - Comments Service (RTDB esquema exacto de Android: `Posts/{postId}/Comments`)
//
// Réplica de CommentActivity.java / AdapterComment.java:
//   Posts/{postId}/Comments/{cId}  = { cId, comment, timestamp: String(millis), id(uid autor),
//                                     type("text"|"gif"|"image"|"video"), pId, [text], [parentId] }
//   Reply/{parentCommentId}/{ts}   = mismo nodo cuando hay `parentId` (CommentActivity.sendComment:975-980)
//   Posts/{postId}/commentCount    = lectura +1 con observeSingleEvent (CommentActivity.updateCommentCount:4725)
//   cLikes/{cId}/{uid} = true      = "me gusta" del comentario (AdapterComment.bindInteractionRow:278-299)
//   Users/{postOwnerId}/Notifications/{ts} + Count/{ts} = aviso al dueño (formato AdapterPost.java:1554)
@MainActor
public final class CommentsService: ObservableObject {
    public static let shared = CommentsService()

    /// Nota: `CommentThreadModel` es interno, por lo que la lista publicada también.
    @Published private(set) var comments: [CommentThreadModel] = []

    private var rawComments: [(key: String, dict: [String: Any])] = []
    private var rawReplies: [String: [(key: String, dict: [String: Any])]] = [:]
    private var likeCounts: [String: Int] = [:]
    private var likedByMe: [String: Bool] = [:]
    /// Perfiles de autores cacheados (mismo patrón que ChatService.peers).
    private var profiles: [String: (name: String, photo: String?)] = [:]
    private var activePostId: String? = nil
    private var isStarted = false
    #if canImport(FirebaseDatabase)
    private var commentsObserver: (handle: DatabaseHandle, remove: () -> Void)?
    private var replyObservers: [String: (handle: DatabaseHandle, remove: () -> Void)] = [:]
    private var likeObservers: [String: (handle: DatabaseHandle, remove: () -> Void)] = [:]
    #endif

    /// Instanciable por vista: dos `DetailPostView` abiertos a la vez no se pisan
    /// (cada uno con su propio servicio y sus observers).
    public init() {}

    /// UID real de la sesión (nunca el id de demo).
    private var myUid: String? { FirebaseService.shared.authenticatedUid }

    // MARK: Arranque (observador de comentarios del post)
    public func ensureStarted(postId: String, postOwnerId: String) {
        guard FirebaseService.shared.canWriteToCloud, let myUid = self.myUid else { return }
        guard activePostId != postId else { return }
        stopObserving()
        activePostId = postId
        isStarted = true
        // Marcar leídas: si el post es mío, limpio el badge (NotificationScreen.onCreate:252-256).
        if postOwnerId == myUid {
            clearRemoteCount(uid: myUid)
        }
        #if canImport(FirebaseDatabase)
        observeComments(postId: postId)
        #endif
    }

    /// Al cerrar la vista se sueltan los observers del post (patrón closeThread de ChatService).
    public func close() {
        stopObserving()
    }

    private func stopObserving() {
        #if canImport(FirebaseDatabase)
        commentsObserver?.remove()
        commentsObserver = nil
        replyObservers.values.forEach { $0.remove() }
        replyObservers = [:]
        likeObservers.values.forEach { $0.remove() }
        likeObservers = [:]
        #endif
        rawComments = []
        rawReplies = [:]
        likeCounts = [:]
        likedByMe = [:]
        comments = []
        activePostId = nil
        isStarted = false
        // `profiles` se conserva como caché de sesiones anteriores.
    }

    #if canImport(FirebaseDatabase)
    private func observeComments(postId: String) {
        let ref = Database.database().reference().child("Posts").child(postId).child("Comments")
        let handle = ref.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self = self, self.activePostId == postId else { return }
                var next: [(key: String, dict: [String: Any])] = []
                for child in snapshot.children {
                    guard let snap = child as? DataSnapshot,
                          let dict = snap.value as? [String: Any] else { continue }
                    next.append((key: snap.key, dict: dict))
                }
                self.rawComments = next
                self.syncAuxiliaryObservers()
                self.fetchMissingProfiles()
                self.rebuild()
            }
        }
        commentsObserver = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
    }

    /// Un observer por comentario visible: respuestas (`Reply/{cId}`) y likes (`cLikes/{cId}`),
    /// igual que AdapterComment.bindReplies:377 y bindInteractionRow:278.
    private func syncAuxiliaryObservers() {
        let cIds = Set(rawComments.map { $0.key })

        for cId in cIds where replyObservers[cId] == nil {
            let ref = Database.database().reference().child("Reply").child(cId)
            let handle = ref.observe(.value) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self = self else { return }
                    var items: [(key: String, dict: [String: Any])] = []
                    for child in snapshot.children {
                        guard let snap = child as? DataSnapshot,
                              let dict = snap.value as? [String: Any] else { continue }
                        items.append((key: snap.key, dict: dict))
                    }
                    self.rawReplies[cId] = items
                    self.rebuild()
                }
            }
            replyObservers[cId] = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
        }
        for (cId, observer) in replyObservers where !cIds.contains(cId) {
            observer.remove()
            replyObservers[cId] = nil
            rawReplies[cId] = nil
        }

        for cId in cIds where likeObservers[cId] == nil {
            let ref = Database.database().reference().child("cLikes").child(cId)
            let handle = ref.observe(.value) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.likeCounts[cId] = snapshot.exists() ? Int(snapshot.childrenCount) : 0
                    if let myUid = self.myUid {
                        self.likedByMe[cId] = snapshot.hasChild(myUid)
                    } else {
                        self.likedByMe[cId] = false
                    }
                    self.rebuild()
                }
            }
            likeObservers[cId] = (handle: handle, remove: { ref.removeObserver(withHandle: handle) })
        }
        for (cId, observer) in likeObservers where !cIds.contains(cId) {
            observer.remove()
            likeObservers[cId] = nil
            likeCounts[cId] = nil
            likedByMe[cId] = nil
        }
    }

    /// Perfiles de los autores (Users/{uid}: name, photo) cacheados, como ChatService.fetchMissingPeers.
    private func fetchMissingProfiles() {
        let uids = Set(
            rawComments.map { CommentsService.stringValue($0.dict["id"]) ?? "" }
                + rawReplies.values.flatMap { items in items.map { CommentsService.stringValue($0.dict["id"]) ?? "" } }
        )
        for uid in uids where !uid.isEmpty && profiles[uid] == nil {
            profiles[uid] = (name: "Artista", photo: nil)
            let ref = Database.database().reference().child("Users").child(uid)
            ref.observeSingleEvent(of: .value) { [weak self] snapshot in
                Task { @MainActor in
                    guard let self = self, let dict = snapshot.value as? [String: Any] else { return }
                    let name = CommentsService.stringValue(dict["name"]) ?? "Artista"
                    let photo = CommentsService.stringValue(dict["photo"])
                        ?? CommentsService.stringValue(dict["image"])
                    self.profiles[uid] = (name: name, photo: photo)
                    self.rebuild()
                }
            }
        }
    }
    #endif

    private func rebuild() {
        // Más recientes primero, como Collections.reverse(loadComments) en Android.
        let sortedComments = rawComments.sorted { lhs, rhs in
            let l = CommentsService.numberValue(lhs.dict["timestamp"]) ?? CommentsService.numberValue(lhs.key) ?? 0
            let r = CommentsService.numberValue(rhs.dict["timestamp"]) ?? CommentsService.numberValue(rhs.key) ?? 0
            return l > r
        }
        comments = sortedComments.map { item -> CommentThreadModel in
            let cId = CommentsService.stringValue(item.dict["cId"]) ?? item.key
            let authorUid = CommentsService.stringValue(item.dict["id"]) ?? ""
            let profile = self.profiles[authorUid]
            let type = CommentsService.stringValue(item.dict["type"]) ?? "text"
            let isMedia = type == "gif" || type == "image" || type == "video"
            let millis = CommentsService.numberValue(item.dict["timestamp"])
                ?? CommentsService.numberValue(item.key) ?? 0

            let sortedReplies = (self.rawReplies[cId] ?? []).sorted { lhs, rhs in
                let l = CommentsService.numberValue(lhs.dict["timestamp"]) ?? CommentsService.numberValue(lhs.key) ?? 0
                let r = CommentsService.numberValue(rhs.dict["timestamp"]) ?? CommentsService.numberValue(rhs.key) ?? 0
                return l < r
            }
            let replies: [CommentReplyModel] = sortedReplies.map { replyItem -> CommentReplyModel in
                let rUid = CommentsService.stringValue(replyItem.dict["id"]) ?? ""
                let rProfile = self.profiles[rUid]
                let rType = CommentsService.stringValue(replyItem.dict["type"]) ?? "text"
                let rIsMedia = rType == "gif" || rType == "image" || rType == "video"
                let rText = rIsMedia
                    ? (CommentsService.stringValue(replyItem.dict["text"]) ?? "")
                    : (CommentsService.stringValue(replyItem.dict["comment"]) ?? "")
                let rMillis = CommentsService.numberValue(replyItem.dict["timestamp"])
                    ?? CommentsService.numberValue(replyItem.key) ?? 0
                return CommentReplyModel(
                    id: replyItem.key,
                    authorName: rProfile?.name ?? "Artista",
                    authorAvatar: rProfile?.photo,
                    text: rText,
                    timeAgo: DateUtils.timeAgo(from: rMillis)
                )
            }

            return CommentThreadModel(
                id: cId,
                authorUid: authorUid,
                authorName: profile?.name ?? "Artista",
                authorAvatar: profile?.photo,
                text: isMedia
                    ? (CommentsService.stringValue(item.dict["text"]) ?? "")
                    : (CommentsService.stringValue(item.dict["comment"]) ?? ""),
                mediaUrl: isMedia ? CommentsService.stringValue(item.dict["comment"]) : nil,
                type: type,
                timeAgo: DateUtils.timeAgo(from: millis),
                likesCount: self.likeCounts[cId] ?? 0,
                isLiked: self.likedByMe[cId] ?? false,
                replies: replies
            )
        }
    }

    // MARK: Envío de comentario (CommentActivity.sendComment:964)
    public func sendComment(postId: String, postOwnerId: String, postOwnerName: String, text: String, parentId: String? = nil) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let myUid = self.myUid, FirebaseService.shared.canWriteToCloud else { return }
        #if canImport(FirebaseDatabase)
        let root = Database.database().reference()
        let millis = "\(Int(Date().timeIntervalSince1970 * 1000))"

        // Esquema idéntico a CommentActivity.sendComment (Android). `timestamp` es String.
        var dict: [String: Any] = [
            "cId": millis,
            "comment": clean,
            "timestamp": millis,
            "id": myUid,
            "type": "text",
            "pId": postId
        ]

        let ref: DatabaseReference
        if let parentId = parentId {
            // Respuesta: se guarda en `Reply/{parentCommentId}/{ts}` (Android:977).
            dict["parentId"] = parentId
            ref = root.child("Reply").child(parentId).child(millis)
        } else {
            ref = root.child("Posts").child(postId).child("Comments").child(millis)
        }

        ref.setValue(dict) { [weak self] error, _ in
            Task { @MainActor in
                guard let self = self else { return }
                guard error == nil else { return }
                if parentId == nil {
                    // Android sólo incrementa el contador en comentarios de primer nivel.
                    self.updateCommentCount(postId: postId)
                    self.bumpLocalCommentCount(postId: postId)
                }
                if myUid != postOwnerId {
                    self.notifyPostOwner(
                        postId: postId,
                        postOwnerId: postOwnerId,
                        commentText: clean,
                        millis: millis
                    )
                }
            }
        }
        #endif
    }

    // MARK: Contador del post (CommentActivity.updateCommentCount:4725, lectura +1 sin transacción)
    private func updateCommentCount(postId: String) {
        #if canImport(FirebaseDatabase)
        let ref = Database.database().reference().child("Posts").child(postId).child("commentCount")
        ref.observeSingleEvent(of: .value) { snapshot in
            var count = 0
            if let number = snapshot.value as? NSNumber {
                count = number.intValue
            } else if let text = snapshot.value as? String, let parsed = Int(text) {
                count = parsed
            }
            ref.setValue(count + 1)
        }
        #endif
    }

    /// Contador local del feed (PostModel.pComments) para que la tarjeta se actualice al volver.
    private func bumpLocalCommentCount(postId: String) {
        guard let index = FirebaseService.shared.posts.firstIndex(where: { $0.id == postId || $0.pId == postId }) else { return }
        var post = FirebaseService.shared.posts[index]
        let current = Int(post.pComments ?? "0") ?? 0
        post.pComments = "\(current + 1)"
        FirebaseService.shared.posts[index] = post
    }

    // MARK: Notificación al dueño del post (formato AdapterPost.java:1554-1564)
    private func notifyPostOwner(postId: String, postOwnerId: String, commentText: String, millis: String) {
        #if canImport(FirebaseDatabase)
        let preview = String(commentText.prefix(40))
        let myName = FirebaseService.shared.currentUser?.name ?? "Un Artista"
        let notification: [String: Any] = [
            "pId": postId,
            "timestamp": millis,
            "pText": "Ha comentado tu publicación: \(preview)",
            "notification": "💬 Nuevo comentario",
            "sId": myUid ?? "",
            "sName": myName,
            "type": "comment"
        ]
        let root = Database.database().reference()
        root.child("Users").child(postOwnerId).child("Notifications").child(millis).setValue(notification)
        root.child("Users").child(postOwnerId).child("Count").child(millis).setValue(true)
        #endif
    }

    // MARK: Marcar leídas (NotificationsService.clearRemoteCount)
    private func clearRemoteCount(uid: String) {
        #if canImport(FirebaseDatabase)
        Database.database().reference().child("Users").child(uid).child("Count").removeValue()
        #endif
    }

    // MARK: "Me gusta" del comentario (AdapterComment.handleReaction, rama simple `cLikes`)
    public func toggleLike(commentId: String) {
        #if canImport(FirebaseDatabase)
        guard let myUid = self.myUid, FirebaseService.shared.canWriteToCloud else { return }
        let ref = Database.database().reference().child("cLikes").child(commentId).child(myUid)
        if likedByMe[commentId] == true {
            ref.removeValue()
        } else {
            ref.setValue(true)
        }
        #endif
    }

    // MARK: Parsing tolerante (mismas utilidades que ChatService / NotificationsService)
    static func stringValue(_ raw: Any?) -> String? {
        if let value = raw as? String { return value }
        if let value = raw as? NSNumber { return value.stringValue }
        return nil
    }

    static func numberValue(_ raw: Any?) -> Double? {
        if let value = raw as? NSNumber { return value.doubleValue }
        if let value = raw as? String { return Double(value) }
        return nil
    }
}

// MARK: - Post Detail & Threaded Comments View (DetailPostActivity.java equivalent)
public struct DetailPostView: View {
    let post: PostModel
    @ObservedObject private var theme = ThemeManager.shared
    /// Instancia propia por vista (no el singleton) para que dos detalles abiertos no colisionen.
    @StateObject private var service = CommentsService()
    @Environment(\.presentationMode) var presentationMode
    @State private var commentText: String = ""
    @State private var replyTarget: CommentThreadModel? = nil

    /// `true` cuando los comentarios provienen del nodo `Posts/{id}/Comments` (sesión real).
    private let usesLiveComments: Bool = FirebaseService.shared.canWriteToCloud

    @State private var demoComments = [
        CommentThreadModel(id: "c1", authorName: "Carlos Méndez", authorAvatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150", text: "¡Increíble afinación en esos pasajes rápidos maestro!", timeAgo: "Hace 15 min", likesCount: 4, isLiked: false, replies: [
            CommentReplyModel(id: "r1", authorName: "Israel Violín", text: "¡Muchas gracias Carlos! Trabajando duro con el metrónomo.", timeAgo: "Hace 5 min")
        ]),
        CommentThreadModel(id: "c2", authorName: "Ana Sofía", authorAvatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150", text: "¿Qué método estás usando para el cambio de posición?", timeAgo: "Hace 1 hora", likesCount: 2, isLiked: false, replies: [])
    ]

    private var comments: [CommentThreadModel] {
        usesLiveComments ? service.comments : demoComments
    }

    public init(post: PostModel) {
        self.post = post
    }

    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    postAndComments
                    commentComposer
                }
            }
            .navigationTitle("Detalle de Publicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .onAppear {
                if usesLiveComments {
                    service.ensureStarted(postId: post.pId ?? post.id, postOwnerId: post.uid)
                }
            }
            .onDisappear {
                if usesLiveComments { service.close() }
            }
        }
    }

    private var postAndComments: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                PostCardView(post: post, canOpenDetail: false)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                HStack {
                    Text("Comentarios (\(comments.count))")
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)

                if comments.isEmpty {
                    Text("Sé el primero en comentar.")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .padding(.vertical, 24)
                }

                commentsList
            }
            .padding(.bottom, 20)
        }
    }

    private var commentsList: some View {
        ForEach(comments) { comment in
            commentRow(comment)
        }
    }

    private func commentRow(_ comment: CommentThreadModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(urlString: comment.authorAvatar, size: 36, isVerified: false)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.authorName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)

                        Text(comment.timeAgo)
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }

                    if let mediaUrl = comment.mediaUrl, let url = URL(string: mediaUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                RoundedRectangle(cornerRadius: 10).fill(theme.borderColor.opacity(0.35))
                            }
                        }
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if !comment.text.isEmpty {
                        Text(comment.text)
                            .font(.caption)
                            .foregroundColor(theme.textPrimary)
                    }
                }

                Spacer()

                Button(action: { toggleLike(for: comment) }) {
                    VStack(spacing: 2) {
                        Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundColor(comment.isLiked ? .red : theme.textSecondary)

                        if comment.likesCount > 0 {
                            Text("\(comment.likesCount)")
                                .font(.system(size: 9))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
            }

            if !comment.replies.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(comment.replies) { reply in
                        HStack(alignment: .top, spacing: 8) {
                            Rectangle()
                                .fill(AppColors.primary.opacity(0.3))
                                .frame(width: 2)
                                .padding(.vertical, 2)

                            AvatarView(urlString: reply.authorAvatar, size: 22, isVerified: false)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(reply.authorName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppColors.primary)
                                Text(reply.text)
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                        .padding(.leading, 36)
                    }
                }
            }

            Button(action: { replyTarget = comment }) {
                Text("Responder")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
            }
            .padding(.leading, 36)
        }
        .padding(12)
        .background(theme.cardColor)
        .cornerRadius(14)
        .padding(.horizontal, 16)
    }

    private var commentComposer: some View {
        VStack(spacing: 0) {
            if let target = replyTarget {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.primary)

                    Text("Respondiendo a \(target.authorName)...")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)

                    Spacer()

                    Button(action: { replyTarget = nil }) {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }

            HStack(spacing: 10) {
                TextField("Escribe un comentario...", text: $commentText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(theme.cardColor)
                    .cornerRadius(20)
                    .foregroundColor(theme.textPrimary)

                Button(action: addComment) {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(AppColors.primary)
                        .clipShape(Circle())
                }
            }
            .padding(12)
        }
        .background(theme.cardColor)
        .border(theme.borderColor, width: 0.5)
    }

    private func toggleLike(for comment: CommentThreadModel) {
        guard usesLiveComments else {
            guard let index = demoComments.firstIndex(where: { $0.id == comment.id }) else { return }
            demoComments[index].isLiked.toggle()
            demoComments[index].likesCount += demoComments[index].isLiked ? 1 : -1
            return
        }
        service.toggleLike(commentId: comment.id)
    }

    private func addComment() {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let parent = replyTarget
        commentText = ""
        replyTarget = nil

        guard usesLiveComments else {
            // Modo demo: se mantiene el comportamiento local sin red.
            if let parentId = parent, let index = demoComments.firstIndex(where: { $0.id == parentId }) {
                demoComments[index].replies.append(
                    CommentReplyModel(id: UUID().uuidString, authorName: "Israel Violín", text: text, timeAgo: "Ahora")
                )
            } else {
                demoComments.append(
                    CommentThreadModel(
                        id: UUID().uuidString,
                        authorName: "Israel Violín",
                        authorAvatar: nil,
                        text: text,
                        timeAgo: "Ahora",
                        likesCount: 0,
                        isLiked: false,
                        replies: []
                    )
                )
            }
            return
        }

        // Sesión real: comentario (o respuesta) en RTDB + contador + notificación al dueño.
        service.sendComment(
            postId: post.pId ?? post.id,
            postOwnerId: post.uid,
            postOwnerName: post.uName ?? "",
            text: text,
            parentId: parent?.id
        )
    }
}

struct CommentThreadModel: Identifiable {
    let id: String
    var authorUid: String = ""
    let authorName: String
    let authorAvatar: String?
    let text: String
    var mediaUrl: String? = nil
    var type: String = "text"
    let timeAgo: String
    var likesCount: Int
    var isLiked: Bool
    var replies: [CommentReplyModel]
}

struct CommentReplyModel: Identifiable {
    let id: String
    let authorName: String
    var authorAvatar: String? = nil
    let text: String
    let timeAgo: String
}
