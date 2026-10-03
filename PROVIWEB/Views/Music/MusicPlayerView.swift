import SwiftUI

// MARK: - Global Floating Mini Player Overlay
public struct MiniPlayerOverlay: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var isFullPlayerPresented: Bool = false
    
    public var body: some View {
        if player.isMiniPlayerVisible, let song = player.currentSong {
            VStack(spacing: 0) {
                // Mini Progress Bar
                ProgressView(value: player.currentTime, total: max(1.0, player.duration))
                    .accentColor(AppColors.primary)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                
                HStack(spacing: 12) {
                    // Cover Art
                    if let cover = song.coverUrl, let url = URL(string: cover) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "music.note")
                        }
                        .frame(width: 44, height: 44)
                        .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.musicPrimary.opacity(0.3))
                            .frame(width: 44, height: 44)
                            .overlay(Image(systemName: "music.note").foregroundColor(.white))
                    }
                    
                    // Song Details
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        
                        Text(song.artist)
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Play/Pause Button
                    Button(action: {
                        player.togglePlayPause()
                    }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundColor(theme.textPrimary)
                            .padding(8)
                    }
                    
                    // Next Button
                    Button(action: {
                        player.playNext()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .foregroundColor(theme.textSecondary)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.cardColor.opacity(0.95))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -2)
                .padding(.horizontal, 12)
                .onTapGesture {
                    isFullPlayerPresented = true
                }
            }
            .sheet(isPresented: $isFullPlayerPresented) {
                MusicPlayerView()
            }
        }
    }
}

// MARK: - Full Screen Glassmorphic Music Player View
public struct MusicPlayerView: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isSeeking: Bool = false
    @State private var seekValue: Double = 0.0
    @State private var rotationAngle: Double = 0.0
    
    public var body: some View {
        ZStack {
            // Ambient Gradient Background
            AppColors.musicGradient
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Top Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("REPRODUCTOR PROVIWEB")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Vinyl / Artwork Disc
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 280, height: 280)
                        .shadow(color: AppColors.musicPrimary.opacity(0.4), radius: 30, x: 0, y: 10)
                    
                    if let cover = player.currentSong?.coverUrl, let url = URL(string: cover) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                        .frame(width: 240, height: 240)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .rotationEffect(.degrees(rotationAngle))
                .onAppear {
                    withAnimation(Animation.linear(duration: 20).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
                
                Spacer()
                
                // Song Title & Artist
                VStack(spacing: 6) {
                    Text(player.currentSong?.title ?? "Sin Canción")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(player.currentSong?.artist ?? "Artista")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 32)
                
                // Scrubber & Times
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { isSeeking ? seekValue : player.currentTime },
                            set: { newValue in
                                seekValue = newValue
                                isSeeking = true
                            }
                        ),
                        in: 0...max(1.0, player.duration),
                        onEditingChanged: { editing in
                            if !editing {
                                player.seek(to: seekValue)
                                isSeeking = false
                            }
                        }
                    )
                    .accentColor(AppColors.primary)
                    
                    HStack {
                        Text(formatDuration(player.currentTime))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text(formatDuration(player.duration))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 32)
                
                // Control Buttons
                HStack(spacing: 36) {
                    Button(action: {}) {
                        Image(systemName: "shuffle")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Button(action: {
                        player.playPrevious()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        player.togglePlayPause()
                    }) {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        player.playNext()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "repeat")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
