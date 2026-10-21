import SwiftUI

// MARK: - AI Violin & Music Professor View
public struct AIProfessorView: View {
    @StateObject private var viewModel = AIProfessorViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode

    public init() {}

    public var body: some View {
        ZStack {
            theme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    Button(action: {
                        if viewModel.isPracticing {
                            viewModel.stopSession()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(theme.textPrimary)
                            .padding(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Profesor IA")
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                        
                        Text(viewModel.currentExercise)
                            .font(.caption2)
                            .foregroundColor(AppColors.primary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.isVoiceFeedbackEnabled.toggle()
                    }) {
                        Image(systemName: viewModel.isVoiceFeedbackEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundColor(viewModel.isVoiceFeedbackEnabled ? AppColors.primary : theme.textSecondary)
                            .padding(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.cardColor)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Camera & Pose Tracker Preview Card
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.85))
                                .frame(height: 300)
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 64))
                                            .foregroundColor(AppColors.primary.opacity(0.8))
                                        
                                        Text(viewModel.isPracticing ? "Rastreo de postura y arco activo" : "Inicia la práctica para encender la cámara")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                )
                            
                            // Live Metrics HUD Overlay
                            HStack(spacing: 16) {
                                MetricPill(title: "Postura", score: viewModel.postureScore, color: AppColors.primary)
                                MetricPill(title: "Afinación", score: viewModel.pitchAccuracyScore, color: AppColors.success)
                                MetricPill(title: "Score Live", score: viewModel.liveScore, color: AppColors.gold)
                            }
                            .padding(.bottom, 12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Tuner Real-Time HUD
                        VStack(spacing: 12) {
                            HStack {
                                Text("Afinador en Tiempo Real")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Text(String(format: "%.1f Hz", viewModel.detectedFrequency))
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            HStack(alignment: .center, spacing: 20) {
                                Text(viewModel.detectedNote)
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.primary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(viewModel.centsDetuned > 5 ? "Sostenido (+)" : (viewModel.centsDetuned < -5 ? "Bemol (-)" : "Afinado Perfecto"))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(abs(viewModel.centsDetuned) <= 5 ? AppColors.success : AppColors.warningOrange)
                                    
                                    // Deviation Gauge Meter
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 8)
                                            
                                            // Center mark
                                            Rectangle()
                                                .fill(AppColors.success)
                                                .frame(width: 2, height: 14)
                                                .offset(x: geo.size.width / 2 - 1, y: -3)
                                            
                                            // Needle
                                            Circle()
                                                .fill(AppColors.primary)
                                                .frame(width: 12, height: 12)
                                                .offset(x: max(0, min(geo.size.width - 12, (geo.size.width / 2) + CGFloat(viewModel.centsDetuned) * 1.5)))
                                        }
                                    }
                                    .frame(height: 14)
                                }
                            }
                        }
                        .padding(16)
                        .background(theme.cardColor)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        
                        // Maestro AI Live Dialogue Box
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "brain.head.profile")
                                .font(.title)
                                .foregroundColor(AppColors.primary)
                                .padding(10)
                                .background(AppColors.primary.opacity(0.12))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Maestro PROVIWEB IA")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textPrimary)
                                
                                Text(viewModel.maestroDialogue)
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                        .background(theme.cardColor)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        
                        // Action Button
                        Button(action: {
                            viewModel.togglePracticeSession()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.isPracticing ? "stop.fill" : "play.fill")
                                Text(viewModel.isPracticing ? "Finalizar Práctica" : "Iniciar Práctica Guiada con IA")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(viewModel.isPracticing ? AppColors.errorRed : AppColors.primary)
                            .cornerRadius(16)
                            .shadow(color: (viewModel.isPracticing ? AppColors.errorRed : AppColors.primary).opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }
}

// MARK: - Metric Pill
struct MetricPill: View {
    let title: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            
            Text("\(Int(score))%")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}
