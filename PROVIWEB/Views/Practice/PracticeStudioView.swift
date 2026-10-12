import SwiftUI
import AVFoundation

// MARK: - Practice Studio Mode & Status Enums
public enum PracticeStudioMode: String, CaseIterable, Identifiable {
    case solo = "Estudio Solo"
    case host = "Transmitir en Vivo"
    case listener = "Unirse a Sala"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .solo: return "music.note"
        case .host: return "antenna.radiowaves.left.and.right"
        case .listener: return "person.2.wave.2.fill"
        }
    }
}

public enum PracticeStudioStatus: String, CaseIterable, Identifiable {
    case practicing = "Practicando en Vivo"
    case tuning = "Afinando Instrumento"
    case paused = "En Pausa"
    case explaining = "Explicando Técnica"
    
    public var id: String { rawValue }
    
    public var color: Color {
        switch self {
        case .practicing: return AppColors.success
        case .tuning: return AppColors.infoBlue
        case .paused: return AppColors.warningOrange
        case .explaining: return AppColors.primary
        }
    }
}

// MARK: - Models for Practice Live & Tonic Sessions
public struct PracticeLiveComment: Identifiable, Hashable {
    public let id: String
    public let userName: String
    public let userPhoto: String
    public let message: String
    public let timestamp: Date
    public let isHost: Bool
    
    public init(
        id: String = UUID().uuidString,
        userName: String,
        userPhoto: String = "",
        message: String,
        timestamp: Date = Date(),
        isHost: Bool = false
    ) {
        self.id = id
        self.userName = userName
        self.userPhoto = userPhoto
        self.message = message
        self.timestamp = timestamp
        self.isHost = isHost
    }
}

public struct ActivePracticeRoom: Identifiable, Hashable {
    public let id: String
    public let hostName: String
    public let hostAvatar: String
    public let title: String
    public let instrument: String
    public let currentPiece: String
    public let listenersCount: Int
    public let bpm: Int
    public let status: PracticeStudioStatus
    
    public init(
        id: String,
        hostName: String,
        hostAvatar: String,
        title: String,
        instrument: String = "Violín",
        currentPiece: String,
        listenersCount: Int,
        bpm: Int = 108,
        status: PracticeStudioStatus = .practicing
    ) {
        self.id = id
        self.hostName = hostName
        self.hostAvatar = hostAvatar
        self.title = title
        self.instrument = instrument
        self.currentPiece = currentPiece
        self.listenersCount = listenersCount
        self.bpm = bpm
        self.status = status
    }
}

public struct PracticeSessionSummary: Hashable {
    public var durationSeconds: Int
    public var listenersCount: Int
    public var reactionsCount: Int
    public var commentsCount: Int
    public var rewardUSD: Double
    public var xpGained: Int
    public var diamondsGained: Int
    public var streakDays: Int
    public var pieceStudied: String
    public var weeklyMinutes: [Int] // Mon to Sun
    
    public init(
        durationSeconds: Int = 2700, // 45 min
        listenersCount: Int = 24,
        reactionsCount: Int = 340,
        commentsCount: Int = 18,
        rewardUSD: Double = 1.00,
        xpGained: Int = 150,
        diamondsGained: Int = 30,
        streakDays: Int = 15,
        pieceStudied: String = "Capricho No. 24 - N. Paganini",
        weeklyMinutes: [Int] = [45, 60, 30, 50, 45, 90, 75]
    ) {
        self.durationSeconds = durationSeconds
        self.listenersCount = listenersCount
        self.reactionsCount = reactionsCount
        self.commentsCount = commentsCount
        self.rewardUSD = rewardUSD
        self.xpGained = xpGained
        self.diamondsGained = diamondsGained
        self.streakDays = streakDays
        self.pieceStudied = pieceStudied
        self.weeklyMinutes = weeklyMinutes
    }
}

// MARK: - Practice Studio ViewModel
@MainActor
public class PracticeStudioViewModel: ObservableObject {
    // Session Mode & Info
    @Published public var currentMode: PracticeStudioMode = .solo
    @Published public var studioStatus: PracticeStudioStatus = .practicing
    @Published public var roomCode: String = "PRACTICE-7492"
    @Published public var practiceGoal: String = "Capricho No. 24 en La menor - N. Paganini"
    @Published public var currentInstrument: String = "Violín"
    @Published public var currentSheetTitle: String = "Paganini - 24 Capricci Op. 1 (Ricordi)"
    @Published public var currentSheetPage: Int = 3
    @Published public var totalSheetPages: Int = 12
    
    // Timer & Session Duration
    @Published public var elapsedTimeSeconds: Int = 0
    @Published public var isPracticeTimerRunning: Bool = false
    @Published public var hasEarnedSessionReward: Bool = false
    
    // Live Stats & Audience
    @Published public var activeListenersCount: Int = 18
    @Published public var reactionsCount: [String: Int] = ["🎻": 84, "👏": 126, "🔥": 92, "❤️": 145, "🎶": 67]
    @Published public var comments: [PracticeLiveComment] = []
    @Published public var commentInputText: String = ""
    
    // Audio Player & Take Recorder
    @Published public var backingTrackSpeed: Float = 1.0
    @Published public var isBackingTrackPlaying: Bool = false
    @Published public var isRecordingTake: Bool = false
    @Published public var recordedTakesCount: Int = 0
    @Published public var lastTakeDurationText: String = "00:45"
    @Published public var isPlayingRecordedTake: Bool = false
    
    // Tap Tempo Calculation (Tonic style)
    private var tapTimes: [Date] = []
    
    // Summary
    @Published public var isSessionSummaryPresented: Bool = false
    @Published public var lastSessionSummary: PracticeSessionSummary? = nil
    
    // Active Live Rooms for Listeners
    @Published public var liveRooms: [ActivePracticeRoom] = [
        ActivePracticeRoom(
            id: "PRACTICE-8812",
            hostName: "Mtro. Alejandro Morales",
            hostAvatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300",
            title: "Ensayo General de Serenata & Mariachi",
            instrument: "Violín",
            currentPiece: "El Son de la Negra - Arreglo Mariachi Gala",
            listenersCount: 29,
            bpm: 132,
            status: .practicing
        ),
        ActivePracticeRoom(
            id: "PRACTICE-4921",
            hostName: "Elena Vargas",
            hostAvatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300",
            title: "Bach: Chacona de la Partita No. 2",
            instrument: "Violín",
            currentPiece: "Partita en Re menor BWV 1004",
            listenersCount: 19,
            bpm: 66,
            status: .practicing
        ),
        ActivePracticeRoom(
            id: "PRACTICE-3109",
            hostName: "Carlos Méndez",
            hostAvatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300",
            title: "Técnica de Arco: Spiccato & Sautillé",
            instrument: "Violonchelo",
            currentPiece: "Estudios Popper Op. 73 No. 6",
            listenersCount: 11,
            bpm: 96,
            status: .explaining
        )
    ]
    
    private var timer: Timer?
    private let firebaseService = FirebaseService.shared
    
    public init() {
        setupMockComments()
    }
    
    public var formattedTime: String {
        let hours = elapsedTimeSeconds / 3600
        let minutes = (elapsedTimeSeconds % 3600) / 60
        let seconds = elapsedTimeSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Timer Control
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
    
    // MARK: - Tap Tempo (Tonic / Android algorithm)
    public func registerTapTempo() {
        let now = Date()
        tapTimes.append(now)
        if tapTimes.count > 5 {
            tapTimes.removeFirst()
        }
        
        if tapTimes.count >= 2 {
            var intervals: [TimeInterval] = []
            for i in 1..<tapTimes.count {
                let diff = tapTimes[i].timeIntervalSince(tapTimes[i-1])
                if diff > 0.15 && diff < 2.0 {
                    intervals.append(diff)
                }
            }
            if !intervals.isEmpty {
                let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
                let calculatedBPM = Int(60.0 / avgInterval)
                if calculatedBPM >= 40 && calculatedBPM <= 240 {
                    MetronomeService.shared.bpm = calculatedBPM
                }
            }
        }
    }
    
    // MARK: - Floating Reactions (Live Studio)
    public func sendReaction(_ emoji: String) {
        reactionsCount[emoji, default: 0] += 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Comments
    public func sendComment() {
        let text = commentInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        let newComment = PracticeLiveComment(
            userName: "Tú",
            message: text,
            isHost: currentMode == .host
        )
        comments.append(newComment)
        commentInputText = ""
    }
    
    // MARK: - Sheet Navigation
    public func nextPage() {
        if currentSheetPage < totalSheetPages {
            currentSheetPage += 1
        }
    }
    
    public func previousPage() {
        if currentSheetPage > 1 {
            currentSheetPage -= 1
        }
    }
    
    // MARK: - Audio Takes
    public func toggleTakeRecording() {
        if isRecordingTake {
            isRecordingTake = false
            recordedTakesCount += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            isRecordingTake = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    // MARK: - Finish Session & Generate Summary
    public func finishSession() {
        stopTimer()
        let totalReactions = reactionsCount.values.reduce(0, +)
        let summary = PracticeSessionSummary(
            durationSeconds: max(elapsedTimeSeconds, 180),
            listenersCount: currentMode == .host ? activeListenersCount : 1,
            reactionsCount: totalReactions,
            commentsCount: comments.count,
            rewardUSD: hasEarnedSessionReward ? 1.00 : 0.50,
            xpGained: 120,
            diamondsGained: 25,
            streakDays: 15,
            pieceStudied: practiceGoal
        )
        self.lastSessionSummary = summary
        self.isSessionSummaryPresented = true
    }
    
    private func setupMockComments() {
        comments = [
            PracticeLiveComment(userName: "Mariana S.", message: "¡Ese cambio de posición en compás 12 estuvo impecable! 👏", isHost: false),
            PracticeLiveComment(userName: "Mtro. Morales", message: "Cuida la presión del dedo índice derecho en el spiccato 🎻", isHost: false),
            PracticeLiveComment(userName: "Jorge Violín", message: "¿Qué afinación estás usando? Suena muy brillante 🔥", isHost: false)
        ]
    }
}

// MARK: - Practice Studio View
public struct PracticeStudioView: View {
    @StateObject private var practiceVM = PracticeStudioViewModel()
    @ObservedObject private var metronome = MetronomeService.shared
    @ObservedObject private var tuner = ChromaticTunerService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isMusePresented: Bool = false
    @State private var isGoalEditorPresented: Bool = false
    @State private var newGoalText: String = ""
    @State private var isTippingPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                headerBar
                
                // Studio Mode Selector (Solo / Host / Listener)
                modeSelectorBar
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        switch practiceVM.currentMode {
                        case .solo:
                            soloPracticeContent
                        case .host:
                            hostLiveStudioContent
                        case .listener:
                            listenerStudioContent
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .sheet(isPresented: $isMusePresented) {
            MuseDeviceView()
        }
        .sheet(isPresented: $practiceVM.isSessionSummaryPresented) {
            if let summary = practiceVM.lastSessionSummary {
                PracticeSessionSummarySheet(summary: summary)
            }
        }
        .sheet(isPresented: $isTippingPresented) {
            PracticeTippingSheet(hostName: "Mtro. Alejandro Morales")
        }
        .sheet(isPresented: $isGoalEditorPresented) {
            goalEditorModal
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            Button(action: {
                practiceVM.stopTimer()
                metronome.stop()
                tuner.stopListening()
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(theme.textPrimary)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Estudio de Práctica")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                
                if practiceVM.currentMode == .host {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("EN VIVO: \(practiceVM.roomCode)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            Button(action: { isMusePresented = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "headphones")
                    Text("Muse")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppColors.primary.opacity(0.12))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.cardColor)
    }
    
    // MARK: - Mode Selector Bar
    private var modeSelectorBar: some View {
        HStack(spacing: 8) {
            ForEach(PracticeStudioMode.allCases) { mode in
                Button(action: {
                    practiceVM.currentMode = mode
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.caption)
                        Text(mode.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(practiceVM.currentMode == mode ? .white : theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(practiceVM.currentMode == mode ? AppColors.primary : theme.cardColor)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
    
    // MARK: - Solo Mode Content
    private var soloPracticeContent: some View {
        VStack(spacing: 18) {
            // Goal Card
            practiceGoalCard
            
            // Practice Timer & Reward Card
            practiceTimerCard
            
            // Backing Track & Take Recorder
            backingTrackAndRecorderCard
            
            // Metronome Card
            metronomeControlCard
            
            // Tuner Card
            chromaticTunerCard
            
            // Finish Practice Button
            finishPracticeButton
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Host Live Studio Content (Tonic HostActivity)
    private var hostLiveStudioContent: some View {
        VStack(spacing: 18) {
            // Live Status & Room Code Card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Código de Sala:")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                            Text(practiceVM.roomCode)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                        }
                        
                        Text(practiceVM.practiceGoal)
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        UIPasteboard.general.string = practiceVM.roomCode
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.primary)
                            .padding(8)
                            .background(AppColors.primary.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
                
                // Status Selector Pill
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PracticeStudioStatus.allCases) { status in
                            Button(action: { practiceVM.studioStatus = status }) {
                                HStack(spacing: 4) {
                                    Circle().fill(status.color).frame(width: 6, height: 6)
                                    Text(status.rawValue)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(practiceVM.studioStatus == status ? status.color.opacity(0.18) : theme.backgroundColor)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(practiceVM.studioStatus == status ? status.color : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(theme.cardColor)
            .cornerRadius(20)
            
            // Live Audience & Reactions Bar
            audienceAndReactionsHUD
            
            // Sheet Music Sync Card
            sheetMusicSyncCard
            
            // Timer Card
            practiceTimerCard
            
            // Metronome Card
            metronomeControlCard
            
            // Live Chat Feed
            liveChatFeedCard
            
            // Finish Practice Button
            finishPracticeButton
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Listener Studio Content (Tonic ListenerActivity)
    private var listenerStudioContent: some View {
        VStack(spacing: 18) {
            // Active Live Rooms List
            VStack(alignment: .leading, spacing: 12) {
                Text("Salas de Estudio Transmitiendo en Vivo")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                
                ForEach(practiceVM.liveRooms) { room in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(AppColors.primaryGradient)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(room.hostName.prefix(1))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(room.hostName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textPrimary)
                                
                                Text(room.currentPiece)
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 6, height: 6)
                                Text("\(room.listenersCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        HStack {
                            Text("BPM: \(room.bpm)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColors.primary.opacity(0.12))
                                .cornerRadius(6)
                            
                            Text(room.status.rawValue)
                                .font(.caption2)
                                .foregroundColor(room.status.color)
                            
                            Spacer()
                            
                            Button(action: {
                                isTippingPresented = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "suit.diamond.fill")
                                    Text("Apoyar")
                                }
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.gold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AppColors.gold.opacity(0.12))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(14)
                    .background(theme.cardColor)
                    .cornerRadius(16)
                }
            }
            
            // Interactive Reactions Pad for Listeners
            VStack(spacing: 12) {
                Text("Reaccionar en Vivo al Músico")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                
                HStack(spacing: 14) {
                    ForEach(["🎻", "👏", "🔥", "❤️", "🎶"], id: \.self) { emoji in
                        Button(action: {
                            practiceVM.sendReaction(emoji)
                        }) {
                            VStack(spacing: 4) {
                                Text(emoji)
                                    .font(.system(size: 28))
                                Text("\(practiceVM.reactionsCount[emoji, default: 0])")
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(theme.backgroundColor)
                            .cornerRadius(14)
                        }
                    }
                }
            }
            .padding(16)
            .background(theme.cardColor)
            .cornerRadius(20)
            
            // Live Chat Feed
            liveChatFeedCard
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Goal Card
    private var practiceGoalCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "target")
                .font(.title2)
                .foregroundColor(AppColors.gold)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Meta de la Sesión")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                Text(practiceVM.practiceGoal)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: {
                newGoalText = practiceVM.practiceGoal
                isGoalEditorPresented = true
            }) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundColor(AppColors.primary)
            }
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(18)
    }
    
    // MARK: - Timer Card
    private var practiceTimerCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Tiempo de Práctica")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                Spacer()
                if practiceVM.hasEarnedSessionReward {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.success)
                        Text("+ $1.00 USD Ganado")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.success)
                    }
                }
            }
            
            Text(practiceVM.formattedTime)
                .font(.system(size: 46, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.primary)
            
            Button(action: { practiceVM.toggleTimer() }) {
                HStack(spacing: 8) {
                    Image(systemName: practiceVM.isPracticeTimerRunning ? "pause.fill" : "play.fill")
                    Text(practiceVM.isPracticeTimerRunning ? "Pausar Sesión" : "Iniciar Contador de Práctica")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(practiceVM.isPracticeTimerRunning ? AppColors.warningOrange : AppColors.primary)
                .cornerRadius(24)
            }
        }
        .padding(20)
        .background(theme.cardColor)
        .cornerRadius(20)
    }
    
    // MARK: - Backing Track & Take Recorder Card
    private var backingTrackAndRecorderCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Pista de Acompañamiento & Grabación")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text("Tomas: \(practiceVM.recordedTakesCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
            }
            
            // Speed Controller Slider
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Velocidad:")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                    Text(String(format: "%.2fx", practiceVM.backingTrackSpeed))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primary)
                    Spacer()
                    Button("1.0x Normal") {
                        practiceVM.backingTrackSpeed = 1.0
                    }
                    .font(.caption2)
                    .foregroundColor(AppColors.primary)
                }
                
                Slider(value: $practiceVM.backingTrackSpeed, in: 0.5...1.5, step: 0.05)
                    .accentColor(AppColors.primary)
            }
            
            // Recorder Buttons
            HStack(spacing: 14) {
                Button(action: { practiceVM.toggleTakeRecording() }) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(practiceVM.isRecordingTake ? Color.red : Color.gray)
                            .frame(width: 10, height: 10)
                        Text(practiceVM.isRecordingTake ? "Detener Grabación" : "Grabar Toma Snippet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(practiceVM.isRecordingTake ? .white : theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(practiceVM.isRecordingTake ? Color.red : theme.backgroundColor)
                    .cornerRadius(12)
                }
                
                if practiceVM.recordedTakesCount > 0 {
                    Button(action: {
                        practiceVM.isPlayingRecordedTake.toggle()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: practiceVM.isPlayingRecordedTake ? "stop.fill" : "play.fill")
                            Text("Oír Toma (\(practiceVM.lastTakeDurationText))")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.primary.opacity(0.12))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(18)
        .background(theme.cardColor)
        .cornerRadius(20)
    }
    
    // MARK: - Metronome Control Card
    private var metronomeControlCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Metrónomo de Alta Precisión")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text("\(metronome.bpm) BPM")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
            }
            
            // Visual Beat Dots
            HStack(spacing: 16) {
                ForEach(1...metronome.timeSignatureBeats, id: \.self) { beat in
                    Circle()
                        .fill(metronome.currentBeat == beat && metronome.isRunning ? AppColors.primary : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .scaleEffect(metronome.currentBeat == beat && metronome.isRunning ? 1.25 : 1.0)
                        .animation(.spring(), value: metronome.currentBeat)
                }
            }
            
            // BPM Slider
            Slider(value: Binding(
                get: { Double(metronome.bpm) },
                set: { metronome.bpm = Int($0) }
            ), in: 40...240, step: 1)
            .accentColor(AppColors.primary)
            
            // Controls + Tap Tempo
            HStack(spacing: 18) {
                Button(action: { if metronome.bpm > 40 { metronome.bpm -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundColor(theme.textSecondary)
                }
                
                Button(action: { metronome.toggle() }) {
                    Image(systemName: metronome.isRunning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(AppColors.primary)
                }
                
                Button(action: { if metronome.bpm < 240 { metronome.bpm += 1 } }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(theme.textSecondary)
                }
                
                Spacer()
                
                Button(action: { practiceVM.registerTapTempo() }) {
                    VStack(spacing: 2) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title3)
                        Text("Tap Tempo")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(AppColors.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.gold.opacity(0.12))
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(theme.cardColor)
        .cornerRadius(20)
    }
    
    // MARK: - Chromatic Tuner Card
    private var chromaticTunerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Afinador Cromático")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button(action: {
                    if tuner.isListening {
                        tuner.stopListening()
                    } else {
                        tuner.startListening()
                    }
                }) {
                    Text(tuner.isListening ? "Detener" : "Activar")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(tuner.isListening ? AppColors.errorRed : AppColors.primary)
                        .cornerRadius(12)
                }
            }
            
            Text(tuner.noteName)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primary)
            
            Text(tuner.tuningStatus.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(tuner.tuningStatus == .inTune ? AppColors.success : theme.textSecondary)
        }
        .padding(20)
        .background(theme.cardColor)
        .cornerRadius(20)
    }
    
    // MARK: - Audience & Reactions HUD
    private var audienceAndReactionsHUD: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(AppColors.primary)
                Text("\(practiceVM.activeListenersCount) Oyentes")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                ForEach(["🎻", "👏", "🔥", "❤️"], id: \.self) { emoji in
                    HStack(spacing: 2) {
                        Text(emoji)
                        Text("\(practiceVM.reactionsCount[emoji, default: 0])")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
        }
        .padding(14)
        .background(theme.cardColor)
        .cornerRadius(16)
    }
    
    // MARK: - Sheet Music Sync Card
    private var sheetMusicSyncCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(AppColors.primary)
                Text(practiceVM.currentSheetTitle)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("Pág. \(practiceVM.currentSheetPage) / \(practiceVM.totalSheetPages)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
            }
            
            HStack(spacing: 14) {
                Button(action: { practiceVM.previousPage() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Anterior")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.backgroundColor)
                    .cornerRadius(10)
                }
                
                Button(action: { practiceVM.nextPage() }) {
                    HStack {
                        Text("Siguiente")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(theme.backgroundColor)
                    .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(18)
    }
    
    // MARK: - Live Chat Feed Card
    private var liveChatFeedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comentarios de la Sesión")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Text("\(practiceVM.comments.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(spacing: 8) {
                ForEach(practiceVM.comments) { comment in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(comment.isHost ? AppColors.gold : AppColors.primary)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(comment.userName.prefix(1))
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(comment.userName)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textPrimary)
                                if comment.isHost {
                                    Text("ANFITRIÓN")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(AppColors.gold)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(AppColors.gold.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                            Text(comment.message)
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(theme.backgroundColor)
                    .cornerRadius(10)
                }
            }
            
            HStack {
                TextField("Escribir comentario a los oyentes...", text: $practiceVM.commentInputText)
                    .font(.caption)
                    .foregroundColor(theme.textPrimary)
                
                Button(action: { practiceVM.sendComment() }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
            .padding(10)
            .background(theme.backgroundColor)
            .cornerRadius(12)
        }
        .padding(16)
        .background(theme.cardColor)
        .cornerRadius(20)
    }
    
    // MARK: - Finish Practice Button
    private var finishPracticeButton: some View {
        Button(action: {
            practiceVM.finishSession()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                Text("Finalizar Práctica & Ver Resumen Tonic")
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.primaryGradient)
            .cornerRadius(18)
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
    
    // MARK: - Goal Editor Modal
    private var goalEditorModal: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Define el repertorio o pasaje técnico que estás trabajando:")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("Meta de estudio...", text: $newGoalText)
                        .padding(12)
                        .background(theme.cardColor)
                        .cornerRadius(12)
                        .foregroundColor(theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        if !newGoalText.isEmpty {
                            practiceVM.practiceGoal = newGoalText
                        }
                        isGoalEditorPresented = false
                    }) {
                        Text("Guardar Meta")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.primary)
                            .cornerRadius(16)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Editar Meta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { isGoalEditorPresented = false }
                }
            }
        }
    }
}

// MARK: - Tonic Practice Session Summary Sheet (SessionSummaryActivity)
public struct PracticeSessionSummarySheet: View {
    public let summary: PracticeSessionSummary
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isSharePresented: Bool = false
    
    private var formattedDuration: String {
        let mins = summary.durationSeconds / 60
        let secs = summary.durationSeconds % 60
        return "\(mins) min \(secs) seg"
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Trophy Card
                        VStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.gold)
                            
                            Text("¡Sesión Completada!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                            
                            Text(summary.pieceStudied)
                                .font(.subheadline)
                                .foregroundColor(theme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 16)
                        
                        // Rewards Banner
                        HStack(spacing: 20) {
                            VStack(spacing: 4) {
                                Text(String(format: "+$%.2f USD", summary.rewardUSD))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.success)
                                Text("P-Wallet")
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Divider().frame(height: 30)
                            
                            VStack(spacing: 4) {
                                Text("+\(summary.xpGained) XP")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                Text("Experiencia")
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Divider().frame(height: 30)
                            
                            VStack(spacing: 4) {
                                Text("+\(summary.diamondsGained) 💎")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.gold)
                                Text("Diamantes")
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        .padding(16)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        
                        // Practice Metrics Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            summaryStatTile(title: "Tiempo Total", value: formattedDuration, icon: "clock.fill", color: AppColors.primary)
                            summaryStatTile(title: "Racha Activa", value: "\(summary.streakDays) Días 🔥", icon: "flame.fill", color: AppColors.warningOrange)
                            summaryStatTile(title: "Oyentes Live", value: "\(summary.listenersCount)", icon: "person.2.fill", color: AppColors.infoBlue)
                            summaryStatTile(title: "Reacciones", value: "\(summary.reactionsCount)", icon: "heart.fill", color: .pink)
                        }
                        
                        // Weekly Progress Bar Chart (Mon-Sun)
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Progreso de Práctica Semanal")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            let days = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
                            HStack(alignment: .bottom, spacing: 12) {
                                ForEach(0..<7, id: \.self) { idx in
                                    let mins = summary.weeklyMinutes[idx]
                                    VStack(spacing: 6) {
                                        Text("\(mins)m")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(theme.textSecondary)
                                        
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(idx == 6 ? AppColors.primary : AppColors.primary.opacity(0.4))
                                            .frame(height: CGFloat(min(mins, 100)))
                                        
                                        Text(days[idx])
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(theme.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: 120)
                        }
                        .padding(18)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        
                        // Share & Close Buttons
                        HStack(spacing: 14) {
                            Button(action: {
                                isSharePresented = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up.fill")
                                    Text("Compartir Logro")
                                }
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppColors.primary.opacity(0.12))
                                .cornerRadius(16)
                            }
                            
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("Aceptar")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppColors.primary)
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Resumen de Sesión")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isSharePresented) {
                PracticeShareSheet(activityItems: ["¡Completé \(formattedDuration) de práctica instrumental de '\(summary.pieceStudied)' en @PROVIWEB! 🎻🔥"])
            }
        }
    }
    
    private func summaryStatTile(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: icon).foregroundColor(color))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
            }
            Spacer()
        }
        .padding(12)
        .background(theme.cardColor)
        .cornerRadius(16)
    }
}

// MARK: - Native Share Sheet
public struct PracticeShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Practice Tipping Sheet
public struct PracticeTippingSheet: View {
    public let hostName: String
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var tipAmount: Int = 10
    @State private var isSuccessAlert: Bool = false
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "suit.diamond.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppColors.gold)
                    
                    Text("Apoyar al Músico en Vivo")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                    
                    Text("Envía diamantes o propina directa a \(hostName) como muestra de aprecio por su talento.")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 14) {
                        ForEach([5, 10, 25, 50], id: \.self) { amount in
                            Button(action: { tipAmount = amount }) {
                                Text("\(amount) 💎")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(tipAmount == amount ? .white : AppColors.gold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(tipAmount == amount ? AppColors.gold : theme.cardColor)
                                    .cornerRadius(14)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isSuccessAlert = true
                    }) {
                        Text("Enviar Propina (\(tipAmount) Diamantes)")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.primary)
                            .cornerRadius(18)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Dar Propina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSuccessAlert) {
                Alert(
                    title: Text("¡Propina Enviada!"),
                    message: Text("Has enviado \(tipAmount) diamantes a \(hostName). ¡Gracias por apoyar la música!"),
                    dismissButton: .default(Text("Aceptar")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}
