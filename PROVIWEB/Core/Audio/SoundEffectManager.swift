import Foundation
import AVFoundation

// MARK: - App Sound Effects Player (Applause, Calling Ringtone, Tap Feedback)
public class SoundEffectManager {
    public static let shared = SoundEffectManager()
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {}
    
    public func playApplause() {
        playSound(named: "aplauso", ext: "mp3")
    }
    
    public func playCallingRingtone() {
        playSound(named: "callinguser", ext: "m4a", loop: true)
    }
    
    public func stopCallingRingtone() {
        audioPlayer?.stop()
    }
    
    public func playMenuTap() {
        playSound(named: "tapmenu", ext: "mp3")
    }
    
    public func playEndTab() {
        playSound(named: "soundendtab", ext: "mp3")
    }
    
    private func playSound(named name: String, ext: String, loop: Bool = false) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds") ??
                        Bundle.main.url(forResource: name, withExtension: ext) else {
            print("[SoundEffectManager] Audio \(name).\(ext) not found in bundle.")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = loop ? -1 : 0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("[SoundEffectManager] Error playing \(name): \(error.localizedDescription)")
        }
    }
}
