import SwiftUI

// MARK: - Admin Moderation & Music Copyright Review View
public struct AdminDashboardView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var pendingSongs = [
        SongReviewItem(id: "s1", title: "Sonata No. 1 en Sol Menor", artist: "Israel Violín", genre: "Clásica", timestamp: "Hace 1 hora"),
        SongReviewItem(id: "s2", title: "El Son de la Madrugada", artist: "Mariachi Real", genre: "Mariachi", timestamp: "Hace 3 horas")
    ]
    @State private var reportedPostsCount: Int = 4
    @State private var verificationRequestsCount: Int = 7
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Quick Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            AdminStatCard(title: "Revisión Canciones", count: "\(pendingSongs.count)", icon: "music.note.list", color: AppColors.primary)
                            AdminStatCard(title: "Posts Reportados", count: "\(reportedPostsCount)", icon: "exclamationmark.triangle.fill", color: AppColors.errorRed)
                            AdminStatCard(title: "Verificaciones", count: "\(verificationRequestsCount)", icon: "graduationcap.fill", color: AppColors.gold)
                            AdminStatCard(title: "Pagos y Retiros", count: "$450 USD", icon: "dollarsign.circle.fill", color: AppColors.success)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Music Copyright Review Queue
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Revisión de Autoría de Canciones")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 16)
                            
                            if pendingSongs.isEmpty {
                                Text("No hay canciones pendientes de revisión.")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                                    .padding(24)
                            } else {
                                ForEach(pendingSongs) { song in
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(song.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(theme.textPrimary)
                                                
                                                Text("Por: \(song.artist) • \(song.genre)")
                                                    .font(.caption)
                                                    .foregroundColor(theme.textSecondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Button(action: {}) {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.title2)
                                                    .foregroundColor(AppColors.primary)
                                            }
                                        }
                                        
                                        HStack(spacing: 12) {
                                            Button(action: {
                                                pendingSongs.removeAll(where: { $0.id == song.id })
                                            }) {
                                                Text("Rechazar")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(AppColors.errorRed)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(AppColors.errorRed.opacity(0.12))
                                                    .cornerRadius(10)
                                            }
                                            
                                            Button(action: {
                                                pendingSongs.removeAll(where: { $0.id == song.id })
                                            }) {
                                                Text("Aprobar Canción")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(AppColors.success)
                                                    .cornerRadius(10)
                                            }
                                        }
                                    }
                                    .padding(14)
                                    .background(theme.cardColor)
                                    .cornerRadius(16)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Panel de Administración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// MARK: - Admin Stat Card
struct AdminStatCard: View {
    let title: String
    let count: String
    let icon: String
    let color: Color
    @ObservedObject private var theme = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(count)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.textPrimary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardColor)
        .cornerRadius(16)
    }
}

struct SongReviewItem: Identifiable {
    let id: String
    let title: String
    let artist: String
    let genre: String
    let timestamp: String
}
