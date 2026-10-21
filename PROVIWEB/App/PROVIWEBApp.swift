import SwiftUI

// MARK: - PROVIWEB iOS Main Application Entry Point
@main
struct PROVIWEBApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !firebaseService.isSessionReady {
                    AppLaunchSplashView()
                } else if firebaseService.isPendingApproval {
                    // Menor de edad pendiente de aprobación (igual que WaitApprovalActivity en Android)
                    WaitApprovalView()
                } else if firebaseService.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(themeManager)
            .environmentObject(firebaseService)
            .environmentObject(audioPlayer)
            .environmentObject(networkMonitor)
            .preferredColorScheme(themeManager.currentTheme == .light ? .light : .dark)
            .onAppear {
                // Red de seguridad: idempotente, garantiza que la sesión se resuelva
                // aunque el AppDelegate no haya podido arrancar Firebase.
                firebaseService.bootstrap()
            }
            .onOpenURL { url in
                handleIncomingDeepLink(url: url)
            }
        }
    }
    
    // MARK: - Deep Link Handler
    private func handleIncomingDeepLink(url: URL) {
        print("[DeepLink] Recibida URL: \(url.absoluteString)")
        
        guard let host = url.host else { return }
        
        if host == "connect" {
            // Web3 Nonce Connection Request (from DApp / Browser)
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let nonce = components?.queryItems?.first(where: { $0.name == "nonce" })?.value ?? ""
            let origin = components?.queryItems?.first(where: { $0.name == "origin" })?.value ?? ""
            print("[Web3 Connect] Solicitud de firma para nonce: \(nonce), origen: \(origin)")
        } else if url.pathComponents.contains("post") {
            let postId = url.lastPathComponent
            print("[DeepLink] Abrir post: \(postId)")
        } else if url.pathComponents.contains("reel") {
            let reelId = url.lastPathComponent
            print("[DeepLink] Abrir reel: \(reelId)")
        } else if url.pathComponents.contains("user") {
            let userId = url.lastPathComponent
            print("[DeepLink] Abrir perfil de usuario: \(userId)")
        }
    }
}

// MARK: - Splash de Arranque (mientras se resuelve la sesión de Firebase)
struct AppLaunchSplashView: View {
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: 64))
                    .foregroundColor(AppColors.primary)

                Text("PROVIWEB")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.primary)

                Text("La Red Social de Músicos, Artistas y Profesores")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)

                ProgressView()
                    .tint(AppColors.primary)
                    .padding(.top, 8)
            }
        }
    }
}
