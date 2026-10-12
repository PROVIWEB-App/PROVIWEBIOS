import SwiftUI

// MARK: - AI Violin & Music Professor View (com.israviolink.app.aiprofessor equivalent)
public struct AIProfessorView: View {
    @StateObject private var viewModel = AIProfessorViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedSection: ProfessorSection = .biomechanics
    @State private var userQuery: String = ""
    @State private var chatHistory: [AIChatMessage] = [
        AIChatMessage(
            isAI: true,
            text: "¡Hola Israel! Soy tu Profesor IA de música y violín. Estoy listo para analizar tu postura con visión artificial, asistirte en afinación o resolver cualquier duda de armonía y técnica. ¿En qué trabajamos hoy?"
        )
    ]
    
    enum ProfessorSection: String, CaseIterable {
        case biomechanics = "Biomecánica"
        case aiTutor = "Tutor Gemini"
        case progress = "Progreso"
    }
    
    struct AIChatMessage: Identifiable {
        let id = UUID()
        let isAI: Bool
        let text: String
    }
    
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
                        Text("Profesor IA PROVIWEB")
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
                
                // Section Picker
                Picker("Sección", selection: $selectedSection) {
                    ForEach(ProfessorSection.allCases, id: \.self) { sec in
                        Text(sec.rawValue).tag(sec)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                // Content Switcher
                Group {
                    switch selectedSection {
                    case .biomechanics:
                        biomechanicsView
                    case .aiTutor:
                        aiTutorView
                    case .progress:
                        studentProgressView
                    }
                }
            }
        }
    }
    
    // MARK: - 1. Biomechanics & Pose Tracking View
    var biomechanicsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Camera & Skeleton Tracker HUD
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.9))
                        .frame(height: 290)
                        .overlay(
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(AppColors.primary.opacity(0.3), lineWidth: 3)
                                        .frame(width: 90, height: 90)
                                    
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 48))
                                        .foregroundColor(AppColors.primary)
                                }
                                
                                Text(viewModel.isPracticing ? "• Rastreo esquelético activo (Codo, Muñeca, Arco)" : "Inicia la práctica para activar visión biomecánica")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                if viewModel.isPracticing {
                                    HStack(spacing: 12) {
                                        Label("Ángulo Codo: 44°", systemImage: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.success)
                                        Label("Arco Paralelo", systemImage: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.success)
                                    }
                                }
                            }
                        )
                    
                    // Live Metrics HUD Overlay
                    HStack(spacing: 12) {
                        MetricPill(title: "Postura", score: viewModel.postureScore, color: AppColors.primary)
                        MetricPill(title: "Afinación", score: viewModel.pitchAccuracyScore, color: AppColors.success)
                        MetricPill(title: "Puntaje", score: viewModel.liveScore, color: AppColors.gold)
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                
                // Tuner Real-Time HUD with Cents Needle
                VStack(spacing: 12) {
                    HStack {
                        Text("Afinador Cromático de Precisión")
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
                            .font(.system(size: 42, weight: .bold, design: .rounded))
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
                                    
                                    Rectangle()
                                        .fill(AppColors.success)
                                        .frame(width: 2, height: 14)
                                        .offset(x: geo.size.width / 2 - 1, y: -3)
                                    
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
                        Text("Consejo en Tiempo Real")
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
                
                // Practice Action Button
                Button(action: {
                    viewModel.togglePracticeSession()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: viewModel.isPracticing ? "stop.fill" : "play.fill")
                        Text(viewModel.isPracticing ? "Finalizar Práctica" : "Iniciar Práctica Guiada con Visión IA")
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
                .padding(.bottom, 28)
            }
        }
    }
    
    // MARK: - 2. Gemini Musical AI Tutor Chat
    var aiTutorView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(chatHistory) { msg in
                        HStack {
                            if !msg.isAI { Spacer() }
                            
                            VStack(alignment: msg.isAI ? .leading : .trailing, spacing: 4) {
                                if msg.isAI {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(AppColors.primary)
                                            .font(.caption2)
                                        Text("Profesor Gemini")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                                
                                Text(msg.text)
                                    .font(.subheadline)
                                    .foregroundColor(msg.isAI ? theme.textPrimary : .white)
                                    .padding(12)
                                    .background(msg.isAI ? theme.cardColor : AppColors.primary)
                                    .cornerRadius(16)
                            }
                            
                            if msg.isAI { Spacer() }
                        }
                    }
                }
                .padding(16)
            }
            
            // Quick Topic Prompts Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PromptPill(title: "¿Cómo mejorar el Spiccato?") {
                        sendTutorQuery("¿Cómo mejorar el golpe de arco Spiccato en el violín?")
                    }
                    PromptPill(title: "Modular de Do M a La m") {
                        sendTutorQuery("¿Cómo realizar una modulación suave de Do Mayor a La Menor usando acordes pivote?")
                    }
                    PromptPill(title: "Cambios de 1ra a 3ra posición") {
                        sendTutorQuery("¿Qué ejercicios recomiendas para cambiar fluidamente de primera a tercera posición en violín?")
                    }
                    PromptPill(title: "Afinación en temperamento igual") {
                        sendTutorQuery("Explícame la diferencia entre el temperamento igual y la afinación pitagórica en cuerdas.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            
            // Input Bar
            HStack(spacing: 10) {
                TextField("Pregúntale al Profesor IA...", text: $userQuery)
                    .padding(10)
                    .background(theme.cardColor)
                    .cornerRadius(20)
                
                Button(action: {
                    sendTutorQuery(userQuery)
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(AppColors.primary)
                        .padding(10)
                }
                .disabled(userQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.backgroundColor)
        }
    }
    
    private func sendTutorQuery(_ query: String) {
        guard !query.isEmpty else { return }
        let userMsg = AIChatMessage(isAI: false, text: query)
        chatHistory.append(userMsg)
        userQuery = ""
        
        // Intelligent musical AI response generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let replyText: String
            if query.contains("Spiccato") {
                replyText = "Para dominar el Spiccato: 1) Localiza el punto de equilibrio de tu arco (aproximadamente a un tercio de la nuez). 2) Deja que el arco rebote de forma pasiva por la elasticidad de la vara, sin empujar con el brazo. 3) Mantén la muñeca derecha elástica y los dedos relajados sobre la nuez."
            } else if query.contains("modulación") || query.contains("Do Mayor") {
                replyText = "Para modular de Do Mayor a su relativo menor (La menor): Utiliza el acorde pivote Re menor (ii en Do M, iv en La m), seguido del dominante Mi Mayor 7 (V7 con sensible Sol#) para resolver con fuerza armónica en La menor (i)."
            } else if query.contains("posición") {
                replyText = "Para el cambio de 1ra a 3ra posición: El pulgar izquierdo debe acompañar el desplazamiento del antebrazo sin tensar el mástil. Utiliza una 'nota guía' con armónico ligero y practica con los estudios de Sevcik Op. 8."
            } else {
                replyText = "Excelente pregunta. En la práctica musical profesional, la clave reside en la economía del movimiento, la relajación de hombros y la escucha interna del timbre antes de emitir cada nota. Sigue practicando 20 minutos diarios enfocado en este objetivo."
            }
            
            let aiMsg = AIChatMessage(isAI: true, text: replyText)
            chatHistory.append(aiMsg)
            viewModel.speakFeedback(replyText)
        }
    }
    
    // MARK: - 3. Student Progress & Skill Tree (MusicProgressActivity)
    var studentProgressView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                // Mastery Level Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nivel de Violinista")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                            Text("Intermedio Avanzado (Nivel 4)")
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundColor(AppColors.primary)
                        }
                        Spacer()
                        Image(systemName: "award.fill")
                            .font(.system(size: 36))
                            .foregroundColor(AppColors.gold)
                    }
                    
                    ProgressView(value: 0.68)
                        .accentColor(AppColors.primary)
                    
                    HStack {
                        Text("68% hacia Nivel Concertino")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        Text("320 / 500 Pts")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)
                    }
                }
                .padding(18)
                .background(theme.cardColor)
                .cornerRadius(20)
                
                // Weekly Practice Stats Grid
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(AppColors.warningOrange)
                        Text("14 Días")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Racha Activa")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(theme.cardColor)
                    .cornerRadius(16)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(AppColors.primary)
                        Text("340 Min")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Esta Semana")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(theme.cardColor)
                    .cornerRadius(16)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppColors.success)
                        Text("94.2%")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Afinación")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(theme.cardColor)
                    .cornerRadius(16)
                }
                
                // Repertoire Mastered
                VStack(alignment: .leading, spacing: 12) {
                    Text("Repertorio Evaluado por IA")
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    
                    PieceProgressRow(title: "Czardas - V. Monti", composer: "Clásico", accuracy: "96% Afinación", isMastered: true)
                    PieceProgressRow(title: "Concierto en La m - J.S. Bach", composer: "Barroco", accuracy: "92% Afinación", isMastered: true)
                    PieceProgressRow(title: "El Son de la Negra", composer: "Mariachi Tradicional", accuracy: "89% Afinación", isMastered: false)
                }
                .padding(16)
                .background(theme.cardColor)
                .cornerRadius(20)
            }
            .padding(16)
        }
    }
}

// MARK: - Subcomponents
struct PromptPill: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.primary.opacity(0.12))
                .cornerRadius(14)
        }
    }
}

struct PieceProgressRow: View {
    let title: String
    let composer: String
    let accuracy: String
    let isMastered: Bool
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        HStack {
            Image(systemName: isMastered ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundColor(isMastered ? AppColors.success : AppColors.warningOrange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)
                Text(composer)
                    .font(.caption2)
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            Text(accuracy)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(AppColors.primary)
        }
        .padding(.vertical, 4)
    }
}

struct MetricPill: View {
    let title: String
    let score: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text(String(format: "%.0f%%", score))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
        }
        .frame(minWidth: 70)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}
