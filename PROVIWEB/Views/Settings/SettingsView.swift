import SwiftUI

// MARK: - App Settings & Preferences View
public struct SettingsView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebase = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var notificationsEnabled: Bool = true
    @State private var soundEffectsEnabled: Bool = true
    @State private var autoPlayVideos: Bool = true
    @State private var isEditProfilePresented: Bool = false
    @State private var isWalletSecurityPresented: Bool = false
    @State private var isVerificationPresented: Bool = false
    @State private var isLegalPresented: Bool = false
    @State private var isDeleteAccountAlertPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    // Profile Shortcut Section
                    Section(header: Text("Cuenta")) {
                        Button(action: { isEditProfilePresented = true }) {
                            HStack {
                                AvatarView(urlString: firebase.currentUser?.image, size: 44, isVerified: true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(firebase.currentUser?.name ?? "Israel Violín")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(theme.textPrimary)
                                    Text("Editar Perfil y Datos Personales")
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        
                        Button(action: { isVerificationPresented = true }) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("Solicitar Insignia de Verificación")
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    
                    // Security & Wallet Section
                    Section(header: Text("Seguridad y Monedero")) {
                        Button(action: { isWalletSecurityPresented = true }) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(AppColors.gold)
                                Text("Seguridad de Wallet & Biometría")
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    
                    // Preferences Section
                    Section(header: Text("Preferencias de la Aplicación")) {
                        Toggle("Notificaciones Push", isOn: $notificationsEnabled)
                        Toggle("Efectos de Sonido al Navegar", isOn: $soundEffectsEnabled)
                        Toggle("Reproducción Automática de Reels", isOn: $autoPlayVideos)
                        
                        Picker("Tema Visual", selection: $theme.currentTheme) {
                            Text("Oscuro (Night)").tag(ThemeMode.night)
                            Text("Atenuado (Dim)").tag(ThemeMode.dim)
                            Text("Claro (Light)").tag(ThemeMode.light)
                        }
                    }
                    
                    // Support & Legal
                    Section(header: Text("Información y Soporte")) {
                        Button(action: { isLegalPresented = true }) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(theme.textSecondary)
                                Text("Términos, Privacidad y Soporte")
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        
                        HStack {
                            Text("Versión de la App")
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                            Text("1.0.0 (Producción)")
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                    
                    // Danger Zone
                    Section {
                        Button(action: { isDeleteAccountAlertPresented = true }) {
                            Text("Eliminar Cuenta Definitivamente")
                                .foregroundColor(AppColors.errorRed)
                        }
                    }
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isEditProfilePresented) {
                EditProfileView()
            }
            .sheet(isPresented: $isWalletSecurityPresented) {
                WalletSecurityView()
            }
            .sheet(isPresented: $isVerificationPresented) {
                VerificationRequestView()
            }
            .sheet(isPresented: $isLegalPresented) {
                LegalAndSupportView()
            }
            .alert(isPresented: $isDeleteAccountAlertPresented) {
                Alert(
                    title: Text("¿Eliminar Cuenta?"),
                    message: Text("Esta acción es irreversible y eliminará todos tus posts, partituras y saldo asociado."),
                    primaryButton: .destructive(Text("Eliminar")) {
                        firebase.isAuthenticated = false
                        presentationMode.wrappedValue.dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}
