import SwiftUI

// MARK: - Musical Achievements & Medals View (AchievementAdapter.java equivalent)
public struct AchievementsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var achievements = [
        AchievementModel(id: "ach1", title: "Primeros 200 Segundos", description: "Completaste tu primera sesión de práctica continua con recompensa.", icon: "stopwatch.fill", color: AppColors.gold, isUnlocked: true, unlockedDate: "12 de Agosto"),
        AchievementModel(id: "ach2", title: "Maestro de la Afinación", description: "Lograste un 98% de precisión en la escala de Sol Mayor con el Profesor IA.", icon: "tuningfork", color: AppColors.primary, isUnlocked: true, unlockedDate: "20 de Agosto"),
        AchievementModel(id: "ach3", title: "Virtuoso del Metrónomo", description: "Mantuviste el pulso a 160 BPM durante más de 5 minutos.", icon: "metronome.fill", color: Color.purple, isUnlocked: true, unlockedDate: "28 de Agosto"),
        AchievementModel(id: "ach4", title: "Embajador Musical", description: "Invitaste a 10 colegas músicos a la comunidad PROVIWEB.", icon: "gift.fill", color: AppColors.success, isUnlocked: true, unlockedDate: "3 de Septiembre"),
        AchievementModel(id: "ach5", title: "Solista Destacado", description: "Subiste 5 obras originales al catálogo de música verificada.", icon: "star.fill", color: Color.orange, isUnlocked: false, unlockedDate: nil)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Level Card
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.gold.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppColors.gold)
                            }
                            
                            Text("Nivel 4: Músico Avanzado")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Has desbloqueado 4 de 5 insignias de maestría.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Achievements List
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Logros e Insignias")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 16)
                            
                            ForEach(achievements) { ach in
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(ach.isUnlocked ? ach.color.opacity(0.15) : Color.gray.opacity(0.15))
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: ach.icon)
                                            .font(.title3)
                                            .foregroundColor(ach.isUnlocked ? ach.color : .gray)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ach.title)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(ach.isUnlocked ? theme.textPrimary : theme.textSecondary)
                                        
                                        Text(ach.description)
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondary)
                                        
                                        if let date = ach.unlockedDate {
                                            Text("Desbloqueado: \(date)")
                                                .font(.system(size: 10))
                                                .foregroundColor(ach.color)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if ach.isUnlocked {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(AppColors.gold)
                                    } else {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(Color.gray.opacity(0.5))
                                    }
                                }
                                .padding(14)
                                .background(theme.cardColor)
                                .cornerRadius(16)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Logros Musicales")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct AchievementModel: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    let unlockedDate: String?
}
