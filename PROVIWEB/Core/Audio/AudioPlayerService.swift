import Foundation
import AVFoundation
import MediaPlayer
import Combine

// MARK: - Global Audio Player Service with LockScreen Controls
public class AudioPlayerService: NSObject, ObservableObject {
    public static let shared = AudioPlayerService()
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    @Published public var currentSong: SongModel?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 1.0
    @Published public var isMiniPlayerVisible: Bool = false
    @Published public var playlistQueue: [SongModel] = []
    @Published public var currentQueueIndex: Int = 0
    
    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error configurando AVAudioSession: \(error)")
        }
    }
    
    public func playSong(_ song: SongModel, fromQueue queue: [SongModel] = []) {
        currentSong = song
        isMiniPlayerVisible = true
        
        if !queue.isEmpty {
            playlistQueue = queue
            if let index = queue.firstIndex(where: { $0.id == song.id }) {
                currentQueueIndex = index
            }
        } else if playlistQueue.isEmpty {
            playlistQueue = [song]
            currentQueueIndex = 0
        }
        
        guard let url = URL(string: song.audioUrl) else { return }
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Periodic time observer
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            if let itemDuration = self.player?.currentItem?.duration.seconds, !itemDuration.isNaN {
                self.duration = itemDuration
            }
            self.updateNowPlayingInfo()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    public func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    public func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }
    
    public func playNext() {
        guard !playlistQueue.isEmpty else { return }
        let nextIndex = (currentQueueIndex + 1) % playlistQueue.count
        currentQueueIndex = nextIndex
        playSong(playlistQueue[nextIndex])
    }
    
    public func playPrevious() {
        guard !playlistQueue.isEmpty else { return }
        let prevIndex = (currentQueueIndex - 1 + playlistQueue.count) % playlistQueue.count
        currentQueueIndex = prevIndex
        playSong(playlistQueue[prevIndex])
    }
    
    @objc private func playerDidFinishPlaying() {
        playNext()
    }
    
    // MARK: - Lock Screen & Control Center Integration
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious()
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
