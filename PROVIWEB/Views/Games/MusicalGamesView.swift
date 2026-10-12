import SwiftUI
import AVFoundation

// MARK: - Musical Games & Ear Training Suite (com.israviolink.app.games 100% equivalent)
public struct MusicalGamesView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedGame: GameType = .pitchPerfect
    @State private var score: Int = 0
    @State private var streak: Int = 0
    
    // Pitch Perfect & Chord State
    @State private var currentQuestionIndex: Int = 0
    @State private var selectedAnswer: String? = nil
    @State private var isAnswerCorrect: Bool? = nil
    
    // Melody Memory State
    @State private var melodySequence: [Int] = [0, 2, 4]
    @State private var playerSequence: [Int] = []
    @State private var isPlayingMelody: Bool = false
    @State private var activeMelodyNote: Int? = nil
    @State private var melodyRound: Int = 1
    
    // Rhythm Master / Tempo Trainer State
    @State private var targetBPM: Double = 120.0
    @State private var tapTimestamps: [Date] = []
    @State private var calculatedBPM: Double = 0.0
    @State private var rhythmFeedback: String = "Toca el pad siguiendo el pulso"
    @State private var rhythmFeedbackColor: Color = .gray
    
    // Multiplayer Arena State
    @State private var multiplayerSecondsRemaining: Int = 30
    @State private var opponentScore: Int = 0
    @State private var isMultiplayerActive: Bool = false
    @State private var multiplayerTimer: Timer? = nil
    
    public enum GameType: String, CaseIterable {
        case pitchPerfect = "Pitch Perfect"
        case melodyMemory = "Memoria Melódica"
        case chordChallenge = "Reto Acordes"
        case scaleMaster = "Escalas & Modos"
        case rhythmMaster = "Rhythm Trainer"
        case multiplayer = "Duelo Arena"
    }
    
    // Sound & Synthesizer Engine
    private let soundManager = SoundEffectManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 14) {
                    // Game Selector Scroll
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(GameType.allCases, id: \.self) { game in
                                Button(action: {
                                    selectedGame = game
                                    resetGameState()
                                }) {
                                    Text(game.rawValue)
                                        .font(.caption)
                                        .fontWeight(selectedGame == game ? .bold : .medium)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedGame == game ? AppColors.primary : theme.cardColor)
                                        .foregroundColor(selectedGame == game ? .white : theme.textPrimary)
                                        .cornerRadius(20)
                                        .shadow(color: selectedGame == game ? AppColors.primary.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)
                    
                    // Score HUD Banner
                    HStack(spacing: 24) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .foregroundColor(AppColors.gold)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Puntos")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.textSecondary)
                                Text("\(score)")
                                    .font(.headline)
                                    .fontWeight(.black)
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(AppColors.warningOrange)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Racha")
                                    .font(.system(size: 10))
                                    .foregroundColor(theme.textSecondary)
                                Text("\(streak)x")
                                    .font(.headline)
                                    .fontWeight(.black)
                                    .foregroundColor(AppColors.warningOrange)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "suit.diamond.fill")
                                .foregroundColor(AppColors.primary)
                            Text("+\(score / 20) QAV")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.primary.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .padding(14)
                    .background(theme.cardColor)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    
                    // Main Game Container
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            switch selectedGame {
                            case .pitchPerfect:
                                pitchPerfectGameView
                            case .melodyMemory:
                                melodyMemoryGameView
                            case .chordChallenge:
                                chordChallengeGameView
                            case .scaleMaster:
                                scaleMasterGameView
                            case .rhythmMaster:
                                rhythmMasterGameView
                            case .multiplayer:
                                multiplayerArenaView
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Juegos Musicales PROVIWEB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        multiplayerTimer?.invalidate()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 1. Pitch Perfect (Oído Absoluto)
    struct NoteQuestion {
        let noteName: String
        let solfege: String
        let frequency: Double
    }
    
    let notePool: [NoteQuestion] = [
        NoteQuestion(noteName: "La4 (A4)", solfege: "La", frequency: 440.0),
        NoteQuestion(noteName: "Do4 (C4)", solfege: "Do", frequency: 261.63),
        NoteQuestion(noteName: "Mi4 (E4)", solfege: "Mi", frequency: 329.63),
        NoteQuestion(noteName: "Sol4 (G4)", solfege: "Sol", frequency: 392.0),
        NoteQuestion(noteName: "Re4 (D4)", solfege: "Re", frequency: 293.66),
        NoteQuestion(noteName: "Fa4 (F4)", solfege: "Fa", frequency: 349.23),
        NoteQuestion(noteName: "Si4 (B4)", solfege: "Si", frequency: 493.88)
    ]
    
    var pitchPerfectGameView: some View {
        let currentNote = notePool[currentQuestionIndex % notePool.count]
        return VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("🎵 Pitch Perfect - Oído Absoluto")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Text("Escucha la frecuencia sonora e identifica la nota musical exacta:")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                soundManager.playTapMenuSound()
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                    Text("Tocar Tono (\(String(format: "%.1f", currentNote.frequency)) Hz)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(AppColors.primaryGradient)
                .cornerRadius(20)
                .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // Solfege Note Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"], id: \.self) { note in
                    Button(action: {
                        selectedAnswer = note
                        let correct = (note == currentNote.solfege)
                        isAnswerCorrect = correct
                        if correct {
                            score += 15
                            streak += 1
                            soundManager.playApplauseSound()
                        } else {
                            streak = 0
                            soundManager.playEndTabSound()
                        }
                    }) {
                        Text(note)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(selectedAnswer == note ? .white : theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedAnswer == note ?
                                (isAnswerCorrect == true ? AppColors.success : AppColors.errorRed) :
                                theme.cardColor
                            )
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardColor, lineWidth: 1))
                    }
                    .disabled(selectedAnswer != nil)
                }
            }
            
            if selectedAnswer != nil {
                Button(action: {
                    selectedAnswer = nil
                    isAnswerCorrect = nil
                    currentQuestionIndex += 1
                }) {
                    Text("Siguiente Nota")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.primary)
                        .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - 2. Melody Memory (Simon Melódico)
    let pianoKeys: [(label: String, color: Color)] = [
        ("Do", .red),
        ("Re", .orange),
        ("Mi", .yellow),
        ("Fa", .green),
        ("Sol", .blue),
        ("La", .purple)
    ]
    
    var melodyMemoryGameView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("🎼 Memoria Melódica - Ronda \(melodyRound)")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Text("Memoriza la secuencia sonora de notas y repítela en el mismo orden:")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                playMelodySequence()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isPlayingMelody ? "waveform" : "play.fill")
                    Text(isPlayingMelody ? "Reproduciendo..." : "Escuchar Secuencia")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(isPlayingMelody ? Color.gray : AppColors.primary)
                .cornerRadius(20)
            }
            .disabled(isPlayingMelody)
            
            // Interactive Colored Melody Buttons
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(0..<pianoKeys.count, id: \.self) { idx in
                    let key = pianoKeys[idx]
                    Button(action: {
                        tapMelodyKey(idx)
                    }) {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(activeMelodyNote == idx ? Color.white : key.color)
                                .frame(width: 50, height: 50)
                                .shadow(color: key.color.opacity(0.5), radius: activeMelodyNote == idx ? 12 : 4)
                            Text(key.label)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.cardColor)
                        .cornerRadius(16)
                        .scaleEffect(activeMelodyNote == idx ? 1.08 : 1.0)
                    }
                    .disabled(isPlayingMelody)
                }
            }
            
            // Progress Indicator
            HStack(spacing: 6) {
                ForEach(0..<melodySequence.count, id: \.self) { i in
                    Circle()
                        .fill(i < playerSequence.count ? AppColors.success : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
        }
    }
    
    private func playMelodySequence() {
        isPlayingMelody = true
        playerSequence.removeAll()
        
        for (step, noteIdx) in melodySequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.7) {
                activeMelodyNote = noteIdx
                soundManager.playTapMenuSound()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.7 + 0.4) {
                activeMelodyNote = nil
                if step == melodySequence.count - 1 {
                    isPlayingMelody = false
                }
            }
        }
    }
    
    private func tapMelodyKey(_ index: Int) {
        soundManager.playTapMenuSound()
        playerSequence.append(index)
        
        let currentStep = playerSequence.count - 1
        if playerSequence[currentStep] != melodySequence[currentStep] {
            // Error!
            soundManager.playEndTabSound()
            streak = 0
            playerSequence.removeAll()
            melodyRound = 1
            melodySequence = [0, 2, 4]
        } else if playerSequence.count == melodySequence.count {
            // Sequence completed successfully!
            soundManager.playApplauseSound()
            score += 25 * melodyRound
            streak += 1
            melodyRound += 1
            melodySequence.append(Int.random(in: 0..<pianoKeys.count))
            playerSequence.removeAll()
        }
    }
    
    // MARK: - 3. Chord Challenge
    struct ChordQuestion {
        let title: String
        let options: [String]
        let correct: String
    }
    
    let chordPool: [ChordQuestion] = [
        ChordQuestion(title: "Do - Mi - Sol (C - E - G)", options: ["Mayor", "Menor", "Aumentado", "Disminuido"], correct: "Mayor"),
        ChordQuestion(title: "La - Do - Mi (A - C - E)", options: ["Mayor", "Menor", "Séptima", "Sus4"], correct: "Menor"),
        ChordQuestion(title: "Sol - Si - Re - Fa (G - B - D - F)", options: ["7ma Dominante", "Mayor 7", "Menor 7", "Disminuido"], correct: "7ma Dominante"),
        ChordQuestion(title: "Si - Re - Fa (B - D - F)", options: ["Mayor", "Menor", "Disminuido", "Aumentado"], correct: "Disminuido"),
        ChordQuestion(title: "Do - Fa - Sol (C - F - G)", options: ["Suspendido 4 (Sus4)", "Mayor", "Menor", "6ta"], correct: "Suspendido 4 (Sus4)")
    ]
    
    var chordChallengeGameView: some View {
        let q = chordPool[currentQuestionIndex % chordPool.count]
        return VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("🎹 Reto de Acordes")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Text("Determina la cualidad armónica del siguiente acorde:")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            
            VStack(spacing: 12) {
                Text(q.title)
                    .font(.title2)
                    .fontWeight(.black)
                    .foregroundColor(AppColors.primary)
                
                Button(action: {
                    soundManager.playTapMenuSound()
                }) {
                    Label("Escuchar Arpegio", systemImage: "speaker.wave.2.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppColors.primary)
                        .cornerRadius(14)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(theme.cardColor)
            .cornerRadius(20)
            
            VStack(spacing: 10) {
                ForEach(q.options, id: \.self) { opt in
                    Button(action: {
                        selectedAnswer = opt
                        let correct = (opt == q.correct)
                        isAnswerCorrect = correct
                        if correct {
                            score += 20
                            streak += 1
                            soundManager.playApplauseSound()
                        } else {
                            streak = 0
                            soundManager.playEndTabSound()
                        }
                    }) {
                        HStack {
                            Text(opt)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            if selectedAnswer == opt {
                                Image(systemName: isAnswerCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isAnswerCorrect == true ? AppColors.success : AppColors.errorRed)
                            }
                        }
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(14)
                    }
                    .disabled(selectedAnswer != nil)
                }
            }
            
            if selectedAnswer != nil {
                Button(action: {
                    selectedAnswer = nil
                    isAnswerCorrect = nil
                    currentQuestionIndex += 1
                }) {
                    Text("Siguiente Acorde")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.primary)
                        .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - 4. Scale & Mode Master
    struct ScaleQuestion {
        let pattern: String
        let options: [String]
        let correct: String
    }
    
    let scalePool: [ScaleQuestion] = [
        ScaleQuestion(pattern: "T - T - ST - T - T - T - ST", options: ["Escala Mayor (Jónica)", "Menor Natural", "Modo Dórico", "Menor Armónica"], correct: "Escala Mayor (Jónica)"),
        ScaleQuestion(pattern: "T - ST - T - T - ST - T - T", options: ["Menor Natural (Eólica)", "Mayor", "Modo Mixolidio", "Pentatónica"], correct: "Menor Natural (Eólica)"),
        ScaleQuestion(pattern: "T - ST - T - T - ST - 1.5T - ST", options: ["Menor Armónica", "Menor Melódica", "Modo Lidio", "Blues"], correct: "Menor Armónica"),
        ScaleQuestion(pattern: "T - ST - T - T - T - ST - T", options: ["Modo Dórico", "Modo Frigio", "Modo Mixolidio", "Locrio"], correct: "Modo Dórico")
    ]
    
    var scaleMasterGameView: some View {
        let q = scalePool[currentQuestionIndex % scalePool.count]
        return VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("🎶 Maestro de Escalas & Modos")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Text("Identifica la estructura intervalar o sonoridad modal:")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            
            VStack(spacing: 12) {
                Text(q.pattern)
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(AppColors.gold)
                Text("(T = Tono, ST = Semitono)")
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(theme.cardColor)
            .cornerRadius(18)
            
            VStack(spacing: 10) {
                ForEach(q.options, id: \.self) { opt in
                    Button(action: {
                        selectedAnswer = opt
                        let correct = (opt == q.correct)
                        isAnswerCorrect = correct
                        if correct {
                            score += 20
                            streak += 1
                            soundManager.playApplauseSound()
                        } else {
                            streak = 0
                            soundManager.playEndTabSound()
                        }
                    }) {
                        HStack {
                            Text(opt)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            if selectedAnswer == opt {
                                Image(systemName: isAnswerCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isAnswerCorrect == true ? AppColors.success : AppColors.errorRed)
                            }
                        }
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(14)
                    }
                    .disabled(selectedAnswer != nil)
                }
            }
            
            if selectedAnswer != nil {
                Button(action: {
                    selectedAnswer = nil
                    isAnswerCorrect = nil
                    currentQuestionIndex += 1
                }) {
                    Text("Siguiente Modo")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.primary)
                        .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - 5. Rhythm Master & Tempo Trainer
    var rhythmMasterGameView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("🥁 Rhythm Master & Tap Tempo")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Text("Objetivo: Mantén el pulso exacto a \(Int(targetBPM)) BPM")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            
            // BPM Target Selector
            HStack(spacing: 12) {
                ForEach([60.0, 90.0, 120.0, 144.0], id: \.self) { bpm in
                    Button(action: {
                        targetBPM = bpm
                        tapTimestamps.removeAll()
                        calculatedBPM = 0.0
                    }) {
                        Text("\(Int(bpm)) BPM")
                            .font(.caption)
                            .fontWeight(targetBPM == bpm ? .bold : .medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(targetBPM == bpm ? AppColors.primary : theme.cardColor)
                            .foregroundColor(targetBPM == bpm ? .white : theme.textPrimary)
                            .cornerRadius(12)
                    }
                }
            }
            
            // Precision Display Card
            VStack(spacing: 8) {
                Text(rhythmFeedback)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(rhythmFeedbackColor)
                
                HStack(spacing: 32) {
                    VStack {
                        Text("BPM Calculado")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                        Text(calculatedBPM > 0 ? "\(Int(calculatedBPM))" : "--")
                            .font(.title)
                            .fontWeight(.black)
                            .foregroundColor(theme.textPrimary)
                    }
                    
                    VStack {
                        Text("Objetivo")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                        Text("\(Int(targetBPM))")
                            .font(.title)
                            .fontWeight(.black)
                            .foregroundColor(AppColors.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(theme.cardColor)
            .cornerRadius(20)
            
            // Giant Rhythm Tap Pad
            Button(action: {
                handleRhythmTap()
            }) {
                ZStack {
                    Circle()
                        .fill(AppColors.primaryGradient)
                        .frame(width: 170, height: 170)
                        .shadow(color: AppColors.primary.opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("TOCA EL BEAT")
                            .font(.caption)
                            .fontWeight(.black)
                            .tracking(1)
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }
    
    private func handleRhythmTap() {
        soundManager.playTapMenuSound()
        let now = Date()
        tapTimestamps.append(now)
        if tapTimestamps.count > 5 {
            tapTimestamps.removeFirst()
        }
        
        guard tapTimestamps.count >= 2 else { return }
        
        var intervals: [Double] = []
        for i in 1..<tapTimestamps.count {
            intervals.append(tapTimestamps[i].timeIntervalSince(tapTimestamps[i-1]))
        }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        calculatedBPM = 60.0 / avgInterval
        
        let delta = abs(calculatedBPM - targetBPM)
        if delta < 3.0 {
            rhythmFeedback = "🎯 ¡PERFECTO! Exactitud milimétrica"
            rhythmFeedbackColor = AppColors.success
            score += 10
            streak += 1
        } else if delta < 8.0 {
            rhythmFeedback = "👍 ¡Buen tempo! Mantén la constancia"
            rhythmFeedbackColor = AppColors.gold
            score += 5
        } else if calculatedBPM > targetBPM {
            rhythmFeedback = "⚠️ Acelerado (+ \(Int(delta)) BPM). Relájate"
            rhythmFeedbackColor = AppColors.warningOrange
            streak = 0
        } else {
            rhythmFeedback = "⚠️ Lento (- \(Int(delta)) BPM). Acelera el pulso"
            rhythmFeedbackColor = AppColors.errorRed
            streak = 0
        }
    }
    
    // MARK: - 6. Multiplayer Arena (Duelo en Tiempo Real)
    var multiplayerArenaView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("🏆 Duelo Multijugador en Tiempo Real")
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Text("Compite 1 vs 1 identificando notas contra otro músico de la red:")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            
            // Scoreboard Duel Card
            HStack(spacing: 20) {
                // You
                VStack(spacing: 6) {
                    AvatarView(urlString: FirebaseService.shared.currentUser?.image, size: 50, isVerified: true)
                    Text("Tú (Israel)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                    Text("\(score) pts")
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(AppColors.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(theme.cardColor)
                .cornerRadius(16)
                
                Text("VS")
                    .font(.headline)
                    .fontWeight(.black)
                    .foregroundColor(AppColors.gold)
                
                // Rival
                VStack(spacing: 6) {
                    AvatarView(urlString: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=500", size: 50, isVerified: true)
                    Text("María (Cello)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                    Text("\(opponentScore) pts")
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundColor(AppColors.errorRed)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(theme.cardColor)
                .cornerRadius(16)
            }
            
            // Match Status
            if isMultiplayerActive {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(AppColors.warningOrange)
                        Text("Tiempo restante: \(multiplayerSecondsRemaining)s")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                    }
                    
                    Text("¿Cuál es la sensible en la escala de Re Mayor?")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(["Do# (C#)", "Do (C)", "Re# (D#)", "Si (B)"], id: \.self) { opt in
                            Button(action: {
                                if opt.contains("Do#") {
                                    score += 25
                                    soundManager.playApplauseSound()
                                } else {
                                    soundManager.playEndTabSound()
                                }
                            }) {
                                Text(opt)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppColors.primary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(18)
                .background(theme.cardColor)
                .cornerRadius(20)
            } else {
                Button(action: {
                    startMultiplayerMatch()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Buscar Rival & Iniciar Duelo")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.primaryGradient)
                    .cornerRadius(18)
                    .shadow(color: AppColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
        }
    }
    
    private func startMultiplayerMatch() {
        isMultiplayerActive = true
        multiplayerSecondsRemaining = 30
        opponentScore = 40
        multiplayerTimer?.invalidate()
        
        multiplayerTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if multiplayerSecondsRemaining > 0 {
                multiplayerSecondsRemaining -= 1
                if multiplayerSecondsRemaining % 4 == 0 {
                    opponentScore += 15
                }
            } else {
                multiplayerTimer?.invalidate()
                isMultiplayerActive = false
                soundManager.playApplauseSound()
            }
        }
    }
    
    private func resetGameState() {
        selectedAnswer = nil
        isAnswerCorrect = nil
        tapTimestamps.removeAll()
        calculatedBPM = 0.0
        rhythmFeedback = "Toca el pad siguiendo el pulso"
        rhythmFeedbackColor = .gray
        playerSequence.removeAll()
    }
}
