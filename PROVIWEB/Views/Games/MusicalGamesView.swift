import SwiftUI

// MARK: - Musical Games & Ear Training View
public struct MusicalGamesView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedGame: GameType = .chordChallenge
    @State private var currentQuestionIndex: Int = 0
    @State private var score: Int = 0
    @State private var selectedAnswer: String? = nil
    @State private var isAnswerCorrect: Bool? = nil
    
    enum GameType: String, CaseIterable {
        case chordChallenge = "Reto de Acordes"
        case intervalTraining = "Entrenamiento Auditivo"
        case rhythmDuel = "Duelo Rítmico"
    }
    
    struct QuizQuestion {
        let title: String
        let options: [String]
        let correctAnswer: String
        let audioHz: Double
    }
    
    let chordQuestions = [
        QuizQuestion(title: "¿Qué tipo de acorde es este?", options: ["Do Mayor", "Do Menor", "Do Aumentado", "Do Disminuido"], correctAnswer: "Do Mayor", audioHz: 523.25),
        QuizQuestion(title: "¿Identifica la cualidad del acorde:", options: ["Mayor", "Menor", "Séptima Dominante", "Suspendido"], correctAnswer: "Menor", audioHz: 440.0),
        QuizQuestion(title: "¿Qué intervalo suena entre estas dos notas?", options: ["5ta Justa", "3ra Mayor", "4ta Justa", "Octava"], correctAnswer: "5ta Justa", audioHz: 659.25)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Score & Game Selector
                    HStack {
                        Picker("Juego", selection: $selectedGame) {
                            ForEach(GameType.allCases, id: \.self) { game in
                                Text(game.rawValue).tag(game)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Score Card
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Puntuación:")
                                .font(.caption)
                                .foregroundColor(theme.textSecondary)
                            Text("\(score) Puntos")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                        }
                        Spacer()
                        Image(systemName: "gamecontroller.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.gold)
                    }
                    .padding(16)
                    .background(theme.cardColor)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    
                    // Question Card
                    let q = chordQuestions[currentQuestionIndex % chordQuestions.count]
                    VStack(spacing: 20) {
                        Text(q.title)
                            .font(.headline)
                            .foregroundColor(theme.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.wave.3.fill")
                                Text("Escuchar Sonido")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(AppColors.primary)
                            .cornerRadius(20)
                        }
                        
                        // Options
                        VStack(spacing: 12) {
                            ForEach(q.options, id: \.self) { option in
                                Button(action: {
                                    selectedAnswer = option
                                    let correct = (option == q.correctAnswer)
                                    isAnswerCorrect = correct
                                    if correct { score += 10 }
                                }) {
                                    HStack {
                                        Text(option)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        if selectedAnswer == option {
                                            Image(systemName: isAnswerCorrect == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(isAnswerCorrect == true ? AppColors.success : AppColors.errorRed)
                                        }
                                    }
                                    .padding(14)
                                    .background(theme.backgroundColor)
                                    .cornerRadius(14)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(theme.cardColor)
                    .cornerRadius(20)
                    .padding(.horizontal, 16)
                    
                    if selectedAnswer != nil {
                        Button(action: {
                            selectedAnswer = nil
                            isAnswerCorrect = nil
                            currentQuestionIndex += 1
                        }) {
                            Text("Siguiente Pregunta")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.primary)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Juegos Musicales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
