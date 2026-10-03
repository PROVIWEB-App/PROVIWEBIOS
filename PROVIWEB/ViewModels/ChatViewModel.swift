import Foundation
import SwiftUI
import Combine
import AVFoundation

// MARK: - Chat ViewModel
@MainActor
public class ChatViewModel: ObservableObject {
    @Published public var chats: [ChatModel] = []
    @Published public var currentMessages: [ChatMessageModel] = []
    @Published public var messageText: String = ""
    @Published public var isRecordingAudio: Bool = false
    @Published public var totalUnreadCount: Int = 2
    
    public init() {
        loadMockChats()
    }
    
    private func loadMockChats() {
        chats = [
            ChatModel(
                id: "chat_1",
                userId: "user_maria_01",
                userName: "María García (Violonchelo)",
                userDp: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=500&auto=format&fit=crop&q=60",
                lastMessage: "¡Excelente ensayo de hoy! Nos vemos el jueves para afinar el cuarteto 🎻",
                lastTimestamp: "10:45 AM",
                unreadCount: 2,
                isOnline: true
            ),
            ChatModel(
                id: "chat_2",
                userId: "entity_mariachi_01",
                userName: "Mariachi Sinfónico Real",
                userDp: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=60",
                lastMessage: "Confirmada la cotización para la serenata del sábado.",
                lastTimestamp: "Ayer",
                unreadCount: 0,
                isOnline: false
            )
        ]
        
        currentMessages = [
            ChatMessageModel(
                id: "msg_1",
                sender: "user_maria_01",
                receiver: "user_demo_violin_001",
                message: "Hola Israel, ¿practicaste el pasaje rápido del tercer movimiento?",
                timestamp: "10:30 AM",
                type: .text
            ),
            ChatMessageModel(
                id: "msg_2",
                sender: "user_demo_violin_001",
                receiver: "user_maria_01",
                message: "Sí, usé el metrónomo de PROVIWEB y ya subí a 130 BPM con el Profesor IA 🎯",
                timestamp: "10:35 AM",
                type: .text
            ),
            ChatMessageModel(
                id: "msg_3",
                sender: "user_maria_01",
                receiver: "user_demo_violin_001",
                message: "¡Excelente ensayo de hoy! Nos vemos el jueves para afinar el cuarteto 🎻",
                timestamp: "10:45 AM",
                type: .text
            )
        ]
    }
    
    public func sendMessage(receiverId: String) {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let newMsg = ChatMessageModel(
            id: UUID().uuidString,
            sender: FirebaseService.shared.currentUserId,
            receiver: receiverId,
            message: messageText,
            timestamp: "Ahora",
            type: .text
        )
        currentMessages.append(newMsg)
        messageText = ""
    }
}

// MARK: - AI Professor ViewModel
@MainActor
public class AIProfessorViewModel: ObservableObject {
    @Published public var isPracticing: Bool = false
    @Published public var currentExercise: String = "Escala de Sol Mayor (Suzuki Libro 1)"
    @Published public var detectedNote: String = "La (A4)"
    @Published public var detectedFrequency: Double = 440.0
    @Published public var centsDetuned: Double = 0.0
    @Published public var pitchAccuracyScore: Double = 94.0
    @Published public var postureScore: Double = 92.0
    @Published public var liveScore: Double = 93.0
    @Published public var maestroDialogue: String = "¡Muy bien! Mantén el arco paralelo al puente."
    @Published public var exerciseProgress: Double = 0.65
    @Published public var isVoiceFeedbackEnabled: Bool = true
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let poseService = PoseEstimationService.shared
    private let tunerService = ChromaticTunerService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupBindings()
    }
    
    private func setupBindings() {
        poseService.$postureScore
            .assign(to: &$postureScore)
        poseService.$feedbackMessage
            .sink { [weak self] msg in
                self?.maestroDialogue = msg
                if self?.isPracticing == true && self?.isVoiceFeedbackEnabled == true {
                    self?.speakFeedback(msg)
                }
            }
            .store(in: &cancellables)
            
        tunerService.$noteName
            .assign(to: &$detectedNote)
        tunerService.$detectedPitch
            .assign(to: &$detectedFrequency)
        tunerService.$centsDetuned
            .assign(to: &$centsDetuned)
    }
    
    public func togglePracticeSession() {
        if isPracticing {
            stopSession()
        } else {
            startSession()
        }
    }
    
    public func startSession() {
        isPracticing = true
        poseService.startCamera()
        tunerService.startListening()
        speakFeedback("Iniciando práctica con el Profesor IA. Colócate frente a la cámara con tu violín.")
    }
    
    public func stopSession() {
        isPracticing = false
        poseService.stopCamera()
        tunerService.stopListening()
        speakFeedback("Excelente sesión. Tu precisión promedio fue de 94 por ciento.")
    }
    
    public func speakFeedback(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-MX")
        utterance.rate = 0.52
        speechSynthesizer.speak(utterance)
    }
}

// MARK: - Practice Studio & Rewards ViewModel
@MainActor
public class PracticeStudioViewModel: ObservableObject {
    @Published public var elapsedTimeSeconds: Int = 0
    @Published public var isPracticeTimerRunning: Bool = false
    @Published public var hasEarnedSessionReward: Bool = false
    
    private var timer: Timer?
    private let firebaseService = FirebaseService.shared
    
    public var formattedTime: String {
        let hours = elapsedTimeSeconds / 3600
        let minutes = (elapsedTimeSeconds % 3600) / 60
        let seconds = elapsedTimeSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    public func toggleTimer() {
        if isPracticeTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    public func startTimer() {
        isPracticeTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTimeSeconds += 1
            
            // Android reward threshold: > 200 seconds ($1.00 balance reward)
            if self.elapsedTimeSeconds >= 200 && !self.hasEarnedSessionReward {
                self.hasEarnedSessionReward = true
                self.firebaseService.addPracticeReward()
            }
        }
    }
    
    public func stopTimer() {
        isPracticeTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
}
