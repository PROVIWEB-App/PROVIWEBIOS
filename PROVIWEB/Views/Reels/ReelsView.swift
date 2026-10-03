import SwiftUI
import AVKit

// MARK: - Full Screen Reels Vertical Swiper View
public struct ReelsView: View {
    @StateObject private var viewModel = ReelsViewModel()
    @State private var showHeartBurst: Bool = false
    @State private var heartBurstPosition: CGPoint = .zero
    
    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if !viewModel.reels.isEmpty {
                TabView(selection: $viewModel.currentReelIndex) {
                    ForEach(0..<viewModel.reels.count, id: \.self) { index in
                        ReelItemView(reel: viewModel.reels[index], onDoubleTap: { pos in
                            heartBurstPosition = pos
                            showHeartBurst = true
                            viewModel.toggleLike(at: index)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                showHeartBurst = false
                            }
                        }, onLikeTap: {
                            viewModel.toggleLike(at: index)
                        }, onCommentTap: {
                            viewModel.isCommentsSheetPresented = true
                        })
                        .tag(index)
                        .rotationEffect(.degrees(-90))
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    }
                }
                .rotationEffect(.degrees(90))
                .frame(width: UIScreen.main.bounds.height, height: UIScreen.main.bounds.width)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            
            // Heart Burst Animation on Double Tap
            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 90))
                    .foregroundColor(.red)
                    .position(heartBurstPosition)
                    .scaleEffect(showHeartBurst ? 1.2 : 0.2)
                    .opacity(showHeartBurst ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.4), value: showHeartBurst)
            }
        }
        .sheet(isPresented: $viewModel.isCommentsSheetPresented) {
            ReelsCommentsSheet()
        }
    }
}

// MARK: - Individual Reel Item View
struct ReelItemView: View {
    let reel: ReelModel
    var onDoubleTap: (CGPoint) -> Void
    var onLikeTap: () -> Void
    var onCommentTap: () -> Void
    
    @State private var discRotation: Double = 0.0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background Video Placeholder / AVPlayer
            Rectangle()
                .fill(LinearGradient(colors: [Color.black.opacity(0.8), Color.blue.opacity(0.3), Color.black], startPoint: .top, endPoint: .bottom))
                .overlay(
                    VStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white.opacity(0.6))
                    }
                )
                .onTapGesture(count: 2) { location in
                    onDoubleTap(location)
                }
            
            // Bottom & Side Overlays
            HStack(alignment: .bottom, spacing: 16) {
                // Left Side: Author & Description
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        AvatarView(urlString: reel.authorDp, size: 36, isVerified: true)
                        
                        Text(reel.authorName ?? "Artista")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Button(action: {}) {
                            Text("Seguir")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppColors.primary)
                                .cornerRadius(12)
                        }
                    }
                    
                    if let caption = reel.caption {
                        Text(caption)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    
                    // Music Disc & Title
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        Text("\(reel.soundTitle ?? "Audio") — \(reel.soundAuthor ?? "PROVIWEB")")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, 32)
                .padding(.leading, 16)
                
                Spacer()
                
                // Right Side: Action Icons
                VStack(spacing: 20) {
                    // Like
                    Button(action: onLikeTap) {
                        VStack(spacing: 4) {
                            Image(systemName: (reel.isLiked ?? false) ? "heart.fill" : "heart")
                                .font(.system(size: 28))
                                .foregroundColor((reel.isLiked ?? false) ? .red : .white)
                            Text("\(reel.likesCount ?? 0)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Comments
                    Button(action: onCommentTap) {
                        VStack(spacing: 4) {
                            Image(systemName: "bubble.right.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                            Text("\(reel.commentsCount ?? 0)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Share
                    Button(action: {}) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.right.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.white)
                            Text("Compartir")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Spinning Music Disc
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )
                        
                        Image(systemName: "music.note")
                            .foregroundColor(AppColors.primary)
                    }
                    .rotationEffect(.degrees(discRotation))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 8).repeatForever(autoreverses: false)) {
                            discRotation = 360
                        }
                    }
                }
                .padding(.bottom, 32)
                .padding(.trailing, 16)
            }
        }
    }
}

// MARK: - Comments Sheet
struct ReelsCommentsSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @State private var commentText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Comentarios")
                .font(.headline)
                .foregroundColor(theme.textPrimary)
                .padding(.vertical, 16)
            
            Divider()
                .background(theme.borderColor)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        AvatarView(urlString: nil, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Carlos López")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                            Text("¡Increíble sonido y ejecución! 🔥🎻")
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimary)
                        }
                    }
                }
                .padding(16)
            }
            
            HStack(spacing: 12) {
                TextField("Escribe un comentario...", text: $commentText)
                    .padding(10)
                    .background(theme.cardColor)
                    .cornerRadius(20)
                
                Button(action: {}) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(16)
        }
        .background(theme.backgroundColor)
    }
}
