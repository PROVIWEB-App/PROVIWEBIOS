import SwiftUI

// MARK: - Invite Artists & Referral Reward Program View
public struct InviteEarnView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isCopied: Bool = false
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero Header Card
                        VStack(spacing: 12) {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.gold)
                            
                            Text("Invita a Músicos y Artistas")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Gana $0.50 USD y 5 Diamantes por cada colega músico que se una a PROVIWEB con tu código.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
                            // Referral Code Pill
                            HStack(spacing: 12) {
                                Text(firebaseService.currentUser?.referralCode ?? "ISRA2026")
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppColors.primaryDark)
                                
                                Button(action: {
                                    UIPasteboard.general.string = firebaseService.currentUser?.referralCode ?? "ISRA2026"
                                    isCopied = true
                                }) {
                                    Image(systemName: "doc.on.doc.fill")
                                        .foregroundColor(AppColors.primaryDark)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(20)
                        }
                        .padding(24)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(24)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Level & Tier Progress Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Nivel de Embajador:")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondary)
                                Text("Plata (Silver)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                Spacer()
                                Text("14 / 15 Referidos")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textPrimary)
                            }
                            
                            ProgressView(value: 14, total: 15)
                                .accentColor(AppColors.gold)
                            
                            HStack(spacing: 16) {
                                TierBadge(title: "Bronce", color: AppColors.bronze, isActive: true)
                                TierBadge(title: "Plata", color: AppColors.silver, isActive: true)
                                TierBadge(title: "Oro", color: AppColors.gold, isActive: false)
                                TierBadge(title: "Diamante", color: AppColors.primary, isActive: false)
                                TierBadge(title: "Leyenda", color: .purple, isActive: false)
                            }
                        }
                        .padding(20)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        
                        // Share Button
                        Button(action: {
                            let shareText = "¡Únete a PROVIWEB, la red social para músicos y profesores! Usa mi código de invitación: \(firebaseService.currentUser?.referralCode ?? "ISRA2026") https://proviweb.com"
                            let av = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootVC = windowScene.windows.first?.rootViewController {
                                rootVC.present(av, animated: true, completion: nil)
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("Compartir Enlace de Invitación")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.primary)
                            .cornerRadius(16)
                            .shadow(color: AppColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Invitar Artistas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isCopied) {
                Alert(title: Text("Copiado"), message: Text("Código de referido copiado al portapapeles."), dismissButton: .default(Text("OK")))
            }
        }
    }
}

// MARK: - Tier Badge
struct TierBadge: View {
    let title: String
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isActive ? color : Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.white))
            
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(isActive ? color : .gray)
        }
        .frame(maxWidth: .infinity)
    }
}
