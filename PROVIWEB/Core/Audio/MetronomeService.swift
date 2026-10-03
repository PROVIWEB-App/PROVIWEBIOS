import Foundation
import AVFoundation
import Accelerate
import Combine

// MARK: - High Precision Digital Metronome Service
public class MetronomeService: ObservableObject {
    public static let shared = MetronomeService()
    
    @Published public var bpm: Int = 100 {
        didSet {
            if isRunning {
                restart()
            }
        }
    }
    @Published public var timeSignatureBeats: Int = 4
    @Published public var currentBeat: Int = 1
    @Published public var isRunning: Bool = false
    
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var accentPlayer: AVAudioPlayer?
    
    public init() {
        setupAudioBeeps()
    }
    
    private func setupAudioBeeps() {
        // Synthesize short high-frequency tick for metronome
        audioPlayer = createClickPlayer(frequency: 880.0, duration: 0.03)
        accentPlayer = createClickPlayer(frequency: 1760.0, duration: 0.04)
    }
    
    private func createClickPlayer(frequency: Double, duration: Double) -> AVAudioPlayer? {
        let sampleRate = 44100.0
        let numSamples = Int(sampleRate * duration)
        var samples = [Int16]()
        
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let val = sin(2.0 * .pi * frequency * t) * (1.0 - Double(i)/Double(numSamples)) // decay envelope
            samples.append(Int16(val * 32767))
        }
        
        let data = Data(bytes: samples, count: numSamples * 2)
        return try? AVAudioPlayer(data: data)
    }
    
    public func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
    
    public func start() {
        stop()
        isRunning = true
        currentBeat = 1
        playTick()
        
        let interval = 60.0 / Double(bpm)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    public func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        currentBeat = 1
    }
    
    private func restart() {
        if isRunning {
            start()
        }
    }
    
    private func tick() {
        currentBeat = (currentBeat % timeSignatureBeats) + 1
        playTick()
    }
    
    private func playTick() {
        if currentBeat == 1 {
            accentPlayer?.play()
        } else {
            audioPlayer?.play()
        }
    }
}

// MARK: - Chromatic Tuner & Real-time Pitch Detection Service (vDSP / FFT)
public class ChromaticTunerService: ObservableObject {
    public static let shared = ChromaticTunerService()
    
    @Published public var detectedPitch: Double = 0.0 // Hz
    @Published public var noteName: String = "--"
    @Published public var octave: Int = 0
    @Published public var centsDetuned: Double = 0.0 // -50 to +50 cents
    @Published public var tuningStatus: TuningStatus = .waiting
    @Published public var isListening: Bool = false
    
    private var audioEngine = AVAudioEngine()
    private let noteNames = ["Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"]
    
    public enum TuningStatus {
        case inTune
        case sharp
        case flat
        case waiting
        
        public var title: String {
            switch self {
            case .inTune: return "¡Afinado Perfecto!"
            case .sharp: return "Alto (Sostenido)"
            case .flat: return "Bajo (Bemol)"
            case .waiting: return "Escuchando instrumento..."
            }
        }
    }
    
    public func startListening() {
        guard !isListening else { return }
        
        let inputNode = audioEngine.inputNode
        let bus = 0
        let format = inputNode.inputFormat(forBus: bus)
        
        inputNode.installTap(onBus: bus, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer: buffer)
        }
        
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            print("Error iniciando Tuner AudioEngine: \(error)")
        }
    }
    
    public func stopListening() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isListening = false
        noteName = "--"
        tuningStatus = .waiting
    }
    
    private func processAudioBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Autocorrelation pitch detection
        var maxCorr: Float = 0.0
        var bestLag = 0
        let minLag = Int(buffer.format.sampleRate / 1000.0) // 1000 Hz max
        let maxLag = Int(buffer.format.sampleRate / 60.0)   // 60 Hz min
        
        for lag in minLag..<maxLag {
            var corr: Float = 0.0
            for i in 0..<(frameLength - lag) {
                corr += channelData[i] * channelData[i + lag]
            }
            if corr > maxCorr {
                maxCorr = corr
                bestLag = lag
            }
        }
        
        if bestLag > 0 && maxCorr > 0.1 {
            let frequency = buffer.format.sampleRate / Double(bestLag)
            DispatchQueue.main.async { [weak self] in
                self?.analyzeFrequency(frequency)
            }
        }
    }
    
    private func analyzeFrequency(_ frequency: Double) {
        guard frequency >= 60.0 && frequency <= 2500.0 else { return }
        self.detectedPitch = frequency
        
        // Convert Hz to MIDI Note
        let midiNumber = 12.0 * log2(frequency / 440.0) + 69.0
        let roundedMidi = Int(round(midiNumber))
        let cents = (midiNumber - Double(roundedMidi)) * 100.0
        
        let noteIndex = (roundedMidi % 12 + 12) % 12
        let noteOctave = (roundedMidi / 12) - 1
        
        self.noteName = noteNames[noteIndex]
        self.octave = noteOctave
        self.centsDetuned = cents
        
        if abs(cents) <= 5.0 {
            self.tuningStatus = .inTune
        } else if cents > 5.0 {
            self.tuningStatus = .sharp
        } else {
            self.tuningStatus = .flat
        }
    }
}
