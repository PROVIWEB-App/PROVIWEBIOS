import SwiftUI

// MARK: - Admin Moderation & Music Copyright Review View
public struct AdminDashboardView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    /// Canciones descartadas a mano en modo demo (sin sesión no llega ningún snapshot
    /// de RTDB, así que el "remove local" sigue siendo el único efecto).
    @State private var locallyDismissedIds: Set<String> = []
    /// Contadores locales de ejemplo (solo se usan cuando no hay sesión real).
    @State private var reportedPostsCount: Int = 4
    @State private var verificationRequestsCount: Int = 7
    @State private var selectedTab: Int = 0
    
    /// Cola de revisión derivada del catálogo YA sincronizado (`FirebaseService.songs`),
    /// sin abrir ningún observador nuevo.
    private var pendingSongs: [SongModel] {
        firebaseService.songs.filter {
            $0.normalizedVerificationStatus == "pending" && !locallyDismissedIds.contains($0.id)
        }
    }
    
    /// Contadores reales de RTDB (`ReportPost` y `Verification`); en modo demo, los locales.
    private var reportedPostsLabel: String {
        firebaseService.canWriteToCloud ? "\(firebaseService.adminReportedPostsCount)" : "\(reportedPostsCount)"
    }
    
    private var verificationRequestsLabel: String {
        firebaseService.canWriteToCloud ? "\(firebaseService.adminPendingVerificationsCount)" : "\(verificationRequestsCount)"
    }
    
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
                            AdminStatCard(title: "Posts Reportados", count: reportedPostsLabel, icon: "exclamationmark.triangle.fill", color: AppColors.errorRed)
                            AdminStatCard(title: "Verificaciones", count: verificationRequestsLabel, icon: "graduationcap.fill", color: AppColors.gold)
                            AdminStatCard(title: "Pagos y Retiros", count: "$450 USD", icon: "dollarsign.circle.fill", color: AppColors.success)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Gestor de Publicidad / Anuncios
                        NavigationLink {
                            AdsManagerView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "megaphone.fill")
                                    .font(.title3)
                                    .foregroundColor(AppColors.gold)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Gestor de Publicidad")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(theme.textPrimary)
                                    Text("Campañas y anuncios promocionales")
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                            .padding(14)
                            .background(theme.cardColor)
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Music Copyright Review Queue (nodo `Songs` de Android)
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
                                                
                                                Text("Por: \(song.artist) • \(song.genre ?? "Sin género")")
                                                    .font(.caption)
                                                    .foregroundColor(theme.textSecondary)
                                                
                                                Text("Enviada el \(reviewDate(song.timestamp))")
                                                    .font(.caption2)
                                                    .foregroundColor(theme.textSecondary)
                                            }
                                             
                                            Spacer()
                                             
                                            Button(action: {
                                                AudioPlayerService.shared.playSong(song)
                                            }) {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.title2)
                                                    .foregroundColor(AppColors.primary)
                                            }
                                        }
                                         
                                        HStack(spacing: 12) {
                                            Button(action: {
                                                moderate(song: song, approve: false)
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
                                                moderate(song: song, approve: true)
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
            .onAppear {
                // Contadores reales: `ReportPost` (denuncias) y `Verification` con status "pending".
                firebaseService.refreshAdminCounters()
            }
        }
    }
    
    /// Aprueba / rechaza en `Songs/{songId}` con sesión real; en demo solo se oculta en local.
    private func moderate(song: SongModel, approve: Bool) {
        if firebaseService.canWriteToCloud {
            if approve {
                firebaseService.approveSong(songId: song.id)
            } else {
                firebaseService.rejectSong(songId: song.id)
            }
        } else {
            locallyDismissedIds.insert(song.id)
        }
    }
    
    /// `timestamp` de Android (String con milisegundos) a fecha legible.
    private func reviewDate(_ millis: String?) -> String {
        guard let millis = millis, let value = Double(millis), value > 0 else { return "fecha no disponible" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: value / 1000))
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
