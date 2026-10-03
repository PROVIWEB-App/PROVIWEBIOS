import SwiftUI

// MARK: - Practice Studio View with Metronome, Tuner & Balance Rewards
public struct PracticeStudioView: View {
    @StateObject private var practiceVM = PracticeStudioViewModel()
    @ObservedObject private var metronome = MetronomeService.shared
    @ObservedObject private var tuner = ChromaticTunerService.shared
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        ZStack {
            theme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
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
                    Text("Estudio de Práctica")
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Image(systemName: "music.quarternote.3")
                        .foregroundColor(AppColors.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.cardColor)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Practice Session Timer Card
                        VStack(spacing: 12) {
                            HStack {
                                Text("Tiempo de Práctica")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                if practiceVM.hasEarnedSessionReward {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.success)
                                        Text("+ $1.00 Ganado")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.success)
                                    }
                                }
                            }
                            
                            Text(practiceVM.formattedTime)
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(AppColors.primary)
                            
                            Button(action: {
                                practiceVM.toggleTimer()
                            }) {
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
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // Digital Metronome Card
                        VStack(spacing: 16) {
                            HStack {
                                Text("Metrónomo")
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
                            
                            HStack(spacing: 24) {
                                Button(action: { if metronome.bpm > 40 { metronome.bpm -= 1 } }) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title)
                                        .foregroundColor(theme.textSecondary)
                                }
                                
                                Button(action: {
                                    metronome.toggle()
                                }) {
                                    Image(systemName: metronome.isRunning ? "stop.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                Button(action: { if metronome.bpm < 240 { metronome.bpm += 1 } }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title)
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                        }
                        .padding(20)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        
                        // Chromatic Tuner Card
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
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
}
