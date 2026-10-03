import SwiftUI

// MARK: - Post Detail & Threaded Comments View (DetailPostActivity.java equivalent)
public struct DetailPostView: View {
    let post: PostModel
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var commentText: String = ""
    @State private var comments = [
        CommentThreadModel(id: "c1", authorName: "Carlos Méndez", authorAvatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150", text: "¡Increíble afinación en esos pasajes rápidos maestro!", timeAgo: "Hace 15 min", likesCount: 4, isLiked: false, replies: [
            CommentReplyModel(id: "r1", authorName: "Israel Violín", text: "¡Muchas gracias Carlos! Trabajando duro con el metrónomo.", timeAgo: "Hace 5 min")
        ]),
        CommentThreadModel(id: "c2", authorName: "Ana Sofía", authorAvatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150", text: "¿Qué método estás usando para el cambio de posición?", timeAgo: "Hace 1 hora", likesCount: 2, isLiked: false, replies: [])
    ]
    
    public init(post: PostModel) {
        self.post = post
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Main Post Card
                            PostCardView(post: post)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            
                            // Comments Section Header
                            HStack {
                                Text("Comentarios (\(comments.count))")
                                    .font(.headline)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            
                            // Comments List
                            ForEach(comments) { comment in
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
                                            
                                            Text(comment.text)
                                                .font(.caption)
                                                .foregroundColor(theme.textPrimary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            if let idx = comments.firstIndex(where: { $0.id == comment.id }) {
                                                comments[idx].isLiked.toggle()
                                                comments[idx].likesCount += comments[idx].isLiked ? 1 : -1
                                            }
                                        }) {
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
                                    
                                    // Replies
                                    if !comment.replies.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(comment.replies) { reply in
                                                HStack(alignment: .top, spacing: 8) {
                                                    Rectangle()
                                                        .fill(AppColors.primary.opacity(0.3))
                                                        .frame(width: 2)
                                                        .padding(.vertical, 2)
                                                    
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
                                }
                                .padding(12)
                                .background(theme.cardColor)
                                .cornerRadius(14)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    
                    // Comment Composer Bar
                    HStack(spacing: 10) {
                        TextField("Escribe un comentario...", text: $commentText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(theme.cardColor)
                            .cornerRadius(20)
                            .foregroundColor(theme.textPrimary)
                        
                        Button(action: {
                            if !commentText.isEmpty {
                                let newComment = CommentThreadModel(id: UUID().uuidString, authorName: "Israel Violín", authorAvatar: nil, text: commentText, timeAgo: "Ahora", likesCount: 0, isLiked: false, replies: [])
                                comments.append(newComment)
                                commentText = ""
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(10)
                                .background(AppColors.primary)
                                .clipShape(Circle())
                        }
                    }
                    .padding(12)
                    .background(theme.cardColor)
                    .border(theme.borderSecondary, width: 0.5)
                }
            }
            .navigationTitle("Detalle de Publicación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct CommentThreadModel: Identifiable {
    let id: String
    let authorName: String
    let authorAvatar: String?
    let text: String
    let timeAgo: String
    var likesCount: Int
    var isLiked: Bool
    var replies: [CommentReplyModel]
}

struct CommentReplyModel: Identifiable {
    let id: String
    let authorName: String
    let text: String
    let timeAgo: String
}
