import SwiftUI
import AVKit

// MARK: - Fullscreen Zoomable Media Viewer (MediaViewActivity.java equivalent)
public struct MediaViewerModal: View {
    let mediaUrl: String
    let isVideo: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    public init(mediaUrl: String, isVideo: Bool = false) {
        self.mediaUrl = mediaUrl
        self.isVideo = isVideo
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if isVideo, let url = URL(string: mediaUrl) {
                VideoPlayer(player: AVPlayer(url: url))
                    .ignoresSafeArea()
            } else if let url = URL(string: mediaUrl) {
                AsyncImage(url: url) { img in
                    img
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    if scale < 1.0 {
                                        scale = 1.0
                                    }
                                    lastScale = scale
                                }
                        )
                } placeholder: {
                    ProgressView()
                        .tint(.white)
                }
            }
            
            // Top Controls Bar
            VStack {
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(16)
                    }
                    Spacer()
                    Button(action: {
                        if let url = URL(string: mediaUrl) {
                            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(av, animated: true)
                            }
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(16)
                    }
                }
                Spacer()
            }
        }
    }
}
