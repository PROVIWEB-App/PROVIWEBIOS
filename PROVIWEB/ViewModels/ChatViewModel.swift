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
            ),
            // Android equivalent: Split-Sheet Collaborative Royalties Agreement
            ChatMessageModel(
                id: "msg_split_1",
                sender: "user_demo_violin_001",
                receiver: "user_maria_01",
                message: "📋 Acuerdo de Colaboración Split Sheet para 'Dueto en Sol Mayor'",
                timestamp: "10:50 AM",
                type: .splitSheet,
                splitSheet: SplitSheetAgreementModel(
                    agreementId: "AGR-92041",
                    songTitle: "Dueto en Sol Mayor para Cuerdas",
                    genre: "Clásica / Cámara",
                    creatorId: "user_demo_violin_001",
                    creatorName: "Israel Violín",
                    creatorRole: "Compositor & 1er Violín",
                    creatorPercentage: 60,
                    creatorSigned: true,
                    collaboratorId: "user_maria_01",
                    collaboratorName: "María García",
                    collaboratorRole: "Arreglista & Cello",
                    collaboratorPercentage: 40,
                    collaboratorSigned: false,
                    status: "pending",
                    digitalCertificateHash: "a8f9c4b2e10d3f8a9e01bc34d56789fa12bcde34",
                    createdTimestamp: Date().timeIntervalSince1970 * 1000
                )
            ),
            // Android equivalent: Job Proposal / Contract in Chat
            ChatMessageModel(
                id: "msg_prop_1",
                sender: "entity_mariachi_01",
                receiver: "user_demo_violin_001",
                message: "💼 Propuesta de Contrato Musical: Serenata Fin de Semana",
                timestamp: "11:00 AM",
                type: .proposal,
                proposal: JobProposalModel(
                    proposalId: "PROP-8812",
                    jobRole: "Primer Violín de Refuerzo",
                    jobEvent: "Serenata de Gala",
                    jobDate: "Sábado 21:00 hrs",
                    jobLocation: "Salón Bellas Artes, CDMX",
                    jobPrice: 120.0,
                    jobCurrency: "USD",
                    jobPaymentFrequency: "Por Servicio",
                    jobStatus: "PENDING",
                    jobDetails: "Repertorio clásico mexicano y sones jaliscienses. Traje de gala requerido."
                )
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
    
    public func sendSplitSheet(
        receiverId: String,
        collaboratorName: String,
        songTitle: String,
        genre: String,
        creatorRole: String,
        creatorPercent: Int,
        collaboratorRole: String,
        collaboratorPercent: Int
    ) {
        let agreementId = "AGR-\(Int.random(in: 10000...99999))"
        let hash = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let split = SplitSheetAgreementModel(
            agreementId: agreementId,
            songTitle: songTitle,
            genre: genre,
            creatorId: FirebaseService.shared.currentUserId,
            creatorName: FirebaseService.shared.currentUser?.name ?? "Músico PROVIWEB",
            creatorRole: creatorRole,
            creatorPercentage: creatorPercent,
            creatorSigned: true,
            collaboratorId: receiverId,
            collaboratorName: collaboratorName,
            collaboratorRole: collaboratorRole,
            collaboratorPercentage: collaboratorPercent,
            collaboratorSigned: false,
            status: "pending",
            digitalCertificateHash: hash
        )
        
        let newMsg = ChatMessageModel(
            id: UUID().uuidString,
            sender: FirebaseService.shared.currentUserId,
            receiver: receiverId,
            message: "📋 Acuerdo Split Sheet generado para '\(songTitle)'",
            timestamp: "Ahora",
            type: .splitSheet,
            splitSheet: split
        )
        currentMessages.append(newMsg)
    }
    
    public func signSplitSheet(messageId: String) {
        if let index = currentMessages.firstIndex(where: { $0.id == messageId }),
           var split = currentMessages[index].splitSheet {
            split.collaboratorSigned = true
            split.status = "signed"
            currentMessages[index].splitSheet = split
        }
    }
    
    public func updateProposalStatus(messageId: String, status: String) {
        if let index = currentMessages.firstIndex(where: { $0.id == messageId }),
           var prop = currentMessages[index].proposal {
            prop.jobStatus = status
            currentMessages[index].proposal = prop
        }
    }
    
    public func sendVoiceNote(receiverId: String, duration: Double) {
        let dummyWaveform: [Float] = [0.2, 0.5, 0.8, 0.4, 0.9, 0.7, 0.3, 0.6, 0.85, 0.5, 0.2]
        let newMsg = ChatMessageModel(
            id: UUID().uuidString,
            sender: FirebaseService.shared.currentUserId,
            receiver: receiverId,
            message: "Nota de voz (\(Int(duration))s)",
            timestamp: "Ahora",
            type: .audio,
            voiceDuration: duration,
            waveform: dummyWaveform
        )
        currentMessages.append(newMsg)
    }
    
    public func sendMediaImage(receiverId: String, imageUrl: String) {
        let newMsg = ChatMessageModel(
            id: UUID().uuidString,
            sender: FirebaseService.shared.currentUserId,
            receiver: receiverId,
            message: "Fotografía adjunta",
            timestamp: "Ahora",
            type: .image,
            mediaUrl: imageUrl
        )
        currentMessages.append(newMsg)
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
