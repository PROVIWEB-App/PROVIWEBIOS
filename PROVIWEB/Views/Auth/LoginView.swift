import SwiftUI
import LocalAuthentication

// MARK: - Login & Authentication View
public struct LoginView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isRegisterPresented: Bool = false
    @State private var isForgotPasswordPresented: Bool = false
    @State private var isBiometricsAvailable: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 28) {
                    Spacer()
                    
                    // Logo & App Name
                    VStack(spacing: 8) {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 64))
                            .foregroundColor(AppColors.primary)
                        
                        Text("PROVIWEB")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.primary)
                        
                        Text("La Red Social de Músicos, Artistas y Profesores")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(theme.textSecondary)
                            TextField("Correo electrónico", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(14)
                        
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(theme.textSecondary)
                            SecureField("Contraseña", text: $password)
                        }
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(14)
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                isForgotPasswordPresented = true
                            }) {
                                Text("¿Olvidaste tu contraseña?")
                                    .font(.caption)
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Login Buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            firebaseService.isAuthenticated = true
                        }) {
                            Text("Iniciar Sesión")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.primary)
                                .cornerRadius(16)
                                .shadow(color: AppColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        
                        // Face ID Button
                        Button(action: {
                            authenticateWithBiometrics()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "faceid")
                                Text("Entrar con Face ID")
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.cardColor)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    // Register Link
                    HStack(spacing: 4) {
                        Text("¿No tienes cuenta?")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                        
                        Button(action: {
                            isRegisterPresented = true
                        }) {
                            Text("Regístrate aquí")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isRegisterPresented) {
                RegisterView()
            }
            .sheet(isPresented: $isForgotPasswordPresented) {
                ForgotPasswordView()
            }
        }
    }
    
    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Inicia sesión en PROVIWEB con Face ID") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        firebaseService.isAuthenticated = true
                    }
                }
            }
        }
    }
}

// MARK: - Register View
struct RegisterView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var instrument: String = "Violín"
    @State private var isSuccess: Bool = false
    
    let instruments = ["Violín", "Viola", "Violonchelo", "Contrabajo", "Trompeta", "Guitarra", "Voz / Canto", "Piano", "Otro"]
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Datos Personales")) {
                        TextField("Nombre completo", text: $name)
                        TextField("Correo electrónico", text: $email)
                            .keyboardType(.emailAddress)
                        SecureField("Contraseña", text: $password)
                    }
                    
                    Section(header: Text("Perfil Musical")) {
                        Picker("Instrumento Principal", selection: $instrument) {
                            ForEach(instruments, id: \.self) { inst in
                                Text(inst)
                            }
                        }
                    }
                    
                    Button(action: {
                        isSuccess = true
                    }) {
                        Text("Crear Cuenta")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Crear Cuenta PROVIWEB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSuccess) {
                Alert(
                    title: Text("¡Bienvenido a PROVIWEB!"),
                    message: Text("Tu cuenta ha sido creada exitosamente."),
                    dismissButton: .default(Text("Comenzar")) {
                        FirebaseService.shared.isAuthenticated = true
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var email: String = ""
    @State private var isSent: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Ingresa tu correo para recibir las instrucciones de restablecimiento de contraseña.")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    
                    TextField("Correo electrónico", text: $email)
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                    
                    Button(action: {
                        isSent = true
                    }) {
                        Text("Enviar Correo")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.primary)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
            .navigationTitle("Recuperar Contraseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSent) {
                Alert(title: Text("Correo Enviado"), message: Text("Revisa tu bandeja de entrada."), dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
    }
}
