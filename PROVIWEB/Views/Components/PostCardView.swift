import SwiftUI
import AVFoundation

// MARK: - Post Card View
public struct PostCardView: View {
    public let post: PostModel
    public var onLike: () -> Void
    public var onComment: () -> Void
    public var onShare: () -> Void
    
    @ObservedObject private var theme = ThemeManager.shared
    @State private var isLikedLocal: Bool = false
    @State private var likesCountLocal: Int = 0
    @State private var isPlayingAudioSnippet: Bool = false
    private let audioPlayer = AudioPlayerService.shared
    
    public init(
        post: PostModel,
        onLike: @escaping () -> Void = {},
        onComment: @escaping () -> Void = {},
        onShare: @escaping () -> Void = {}
    ) {
        self.post = post
        self.onLike = onLike
        self.onComment = onComment
        self.onShare = onShare
        _isLikedLocal = State(initialValue: post.likedByCurrentUser ?? false)
        _likesCountLocal = State(initialValue: Int(post.pLikes ?? "0") ?? 0)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                AvatarView(urlString: post.uDp, size: 44, isVerified: true)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.uName ?? "Usuario PROVIWEB")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppColors.primary)
                            .font(.subheadline)
                    }
                    
                    HStack(spacing: 6) {
                        if let feeling = post.feeling, !feeling.isEmpty {
                            Text("— se siente \(feeling)")
                                .font(.caption)
                                .foregroundColor(AppColors.primary)
                        }
                        
                        if let location = post.location, !location.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                Text(location)
                            }
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(theme.textSecondary)
                }
            }
            
            // Post Text
            if let title = post.pTitle, !title.isEmpty {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
            }
            
            if let descr = post.pDescr, !descr.isEmpty {
                Text(descr)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimary.opacity(0.9))
            }
            
            // Post Image Attachment
            if let img = post.pImage, !img.isEmpty, let url = URL(string: img) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxHeight: 320)
                            .cornerRadius(12)
                            .clipped()
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    default:
                        ShimmerLoadingView()
                            .frame(height: 220)
                            .cornerRadius(12)
                    }
                }
            }
            
            // Audio Snippet Player (if post has audio)
            if let audio = post.pAudio, !audio.isEmpty {
                HStack(spacing: 12) {
                    Button(action: {
                        let song = SongModel(title: post.pTitle ?? "Audio Post", artist: post.uName ?? "PROVIWEB", audioUrl: audio)
                        audioPlayer.playSong(song)
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pista de audio adjunta")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(theme.textPrimary)
                        
                        AudioWaveformView(samples: [0.3, 0.6, 0.9, 0.4, 0.7, 0.5, 0.8, 0.2, 0.6, 0.9, 0.4])
                            .frame(height: 18)
                    }
                }
                .padding(10)
                .background(theme.cardColor.opacity(0.8))
                .cornerRadius(10)
            }
            
            Divider()
                .background(theme.borderColor)
            
            // Actions Bar
            HStack(spacing: 24) {
                // Like Button
                Button(action: {
                    isLikedLocal.toggle()
                    likesCountLocal += isLikedLocal ? 1 : -1
                    onLike()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isLikedLocal ? "heart.fill" : "heart")
                            .foregroundColor(isLikedLocal ? .red : theme.textSecondary)
                            .scaleEffect(isLikedLocal ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isLikedLocal)
                        
                        Text("\(likesCountLocal)")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                
                // Comment Button
                Button(action: onComment) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(theme.textSecondary)
                        Text(post.pComments ?? "0")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                
                // Share Button
                Button(action: onShare) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrowshape.turn.up.right")
                            .foregroundColor(theme.textSecondary)
                        Text(post.pShare ?? "0")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "bookmark")
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Avatar View
public struct AvatarView: View {
    public let urlString: String?
    public var size: CGFloat = 40
    public var isVerified: Bool = false
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let urlStr = urlString, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: size, height: size)
                    .foregroundColor(AppColors.primary)
            }
            
            if isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: size * 0.35))
                    .foregroundColor(AppColors.primary)
                    .background(Circle().fill(Color.white).frame(width: size * 0.35, height: size * 0.35))
                    .offset(x: 2, y: 2)
            }
        }
    }
}

// MARK: - Audio Waveform View
public struct AudioWaveformView: View {
    public let samples: [Float]
    
    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<samples.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary)
                    .frame(width: 3, height: CGFloat(samples[i]) * 20)
            }
        }
    }
}

// MARK: - Shimmer Loading View
public struct ShimmerLoadingView: View {
    @State private var phase: CGFloat = 0
    
    public var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.35), Color.gray.opacity(0.15)]),
            startPoint: .init(x: phase - 1, y: 0),
            endPoint: .init(x: phase + 1, y: 0)
        )
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }
}
