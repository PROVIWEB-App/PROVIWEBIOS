import SwiftUI
import LocalAuthentication
import Security

// MARK: - Login & Authentication View
public struct LoginView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isRegisterPresented: Bool = false
    @State private var isForgotPasswordPresented: Bool = false
    @State private var errorMessage: String?

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
                                .disableAutocorrection(true)
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
                            performLogin()
                        }) {
                            HStack(spacing: 8) {
                                if firebaseService.isAuthBusy {
                                    ProgressView().tint(.white)
                                }
                                Text("Iniciar Sesión")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.primary)
                            .cornerRadius(16)
                            .shadow(color: AppColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .disabled(firebaseService.isAuthBusy)

                        // Face ID Button
                        Button(action: {
                            authenticateWithBiometrics()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "faceid")
                                Text(SessionKeychain.load() == nil
                                     ? "Activar Face ID (guarda tu sesión)"
                                     : "Entrar con Face ID")
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

                    // Demo mode + Register Link
                    VStack(spacing: 14) {
                        Button(action: {
                            firebaseService.enterDemoMode()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Explorar sin cuenta (modo demo)")
                            }
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primary)
                        }

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
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isRegisterPresented) {
                // Sin acciones aquí a propósito: `signUp` activa la sesión (o arma
                // `isPendingApproval` en menores) y la raíz de PROVIWEBApp cambia sola
                // a MainTabView/WaitApprovalView. Presentar un cover además era redundante
                // y provocaba avisos de presentación sobre una vista ya desmontada.
                RegisterView { _ in }
            }
            .sheet(isPresented: $isForgotPasswordPresented) {
                ForgotPasswordView()
            }
            .alert(isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Atención"),
                    message: Text(errorMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Acciones
    private func performLogin() {
        firebaseService.signIn(email: email, password: password) { result in
            switch result {
            case .success:
                // Se persiste la sesión para permitir el acceso con Face ID la próxima vez.
                if !self.email.isEmpty && !self.password.isEmpty {
                    SessionKeychain.save(email: self.email, password: self.password)
                }
            case .failure(let error):
                self.errorMessage = self.firebaseService.authError ?? error.localizedDescription
            }
        }
    }

    private func authenticateWithBiometrics() {
        guard let credential = SessionKeychain.load() else {
            errorMessage = "Inicia una vez con tu contraseña para activar el acceso con Face ID."
            return
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            errorMessage = "Este dispositivo no tiene Face ID / Touch ID configurado."
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Inicia sesión en PROVIWEB con Face ID"
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    self.firebaseService.signIn(email: credential.email, password: credential.password) { result in
                        if case .failure(let failure) = result {
                            self.errorMessage = self.firebaseService.authError ?? failure.localizedDescription
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Outcomes del registro
public enum RegisterOutcome: Equatable {
    case done
    case pendingApproval
}

// MARK: - Register View
struct RegisterView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode

    private let onFinished: (RegisterOutcome) -> Void

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var phone: String = ""
    @State private var instrument: String = "Violín"
    @State private var isMinor: Bool = false
    @State private var verificationID: String?
    @State private var showOTP: Bool = false
    @State private var activeAlert: RegisterAlert?

    private enum RegisterAlert: Identifiable {
        case error(String)
        case success

        var id: String {
            switch self {
            case .error(let message): return "error-\(message)"
            case .success: return "success"
            }
        }
    }

    let instruments = ["Violín", "Viola", "Violonchelo", "Contrabajo", "Trompeta", "Guitarra", "Voz / Canto", "Piano", "Otro"]

    init(onFinished: @escaping (RegisterOutcome) -> Void) {
        self.onFinished = onFinished
    }

    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                Form {
                    Section(header: Text("Datos Personales")) {
                        TextField("Nombre completo", text: $name)
                        TextField("Correo electrónico", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("Contraseña (mínimo 6 caracteres)", text: $password)
                        TextField("Teléfono (opcional, con código de país)", text: $phone)
                            .keyboardType(.phonePad)
                    }

                    Section(header: Text("Perfil Musical")) {
                        Picker("Instrumento Principal", selection: $instrument) {
                            ForEach(instruments, id: \.self) { inst in
                                Text(inst)
                            }
                        }
                    }

                    Section(
                        header: Text("Seguridad de menores"),
                        footer: Text("Si eres menor de edad tu cuenta quedará en revisión por nuestro equipo pedagógico, igual que en Android.")
                    ) {
                        Toggle(isOn: $isMinor) {
                            Text("Soy menor de edad")
                        }
                    }

                    Button(action: {
                        register()
                    }) {
                        HStack(spacing: 8) {
                            if firebaseService.isAuthBusy {
                                ProgressView().tint(.white)
                            }
                            Text("Crear Cuenta")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(firebaseService.isAuthBusy)
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
            .sheet(isPresented: $showOTP, onDismiss: {
                finish(with: .done)
            }) {
                OTPVerificationView(
                    phoneNumber: normalizedPhone(),
                    verificationID: verificationID
                ) { _ in
                    showOTP = false
                }
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .error(let message):
                    return Alert(
                        title: Text("No se pudo crear la cuenta"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                case .success:
                    return Alert(
                        title: Text("¡Bienvenido a PROVIWEB!"),
                        message: Text("Tu cuenta ha sido creada exitosamente."),
                        dismissButton: .default(Text("Comenzar")) {
                            finish(with: .done)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Registro real contra Firebase Auth
    private func register() {
        guard !firebaseService.isAuthBusy else { return }

        firebaseService.signUp(
            name: name,
            email: email,
            password: password,
            instrument: instrument,
            phone: phone.isEmpty ? nil : normalizedPhone(),
            isMinor: isMinor
        ) { result in
            switch result {
            case .failure(let error):
                self.activeAlert = .error(self.firebaseService.authError ?? error.localizedDescription)
            case .success:
                if self.isMinor {
                    self.finish(with: .pendingApproval)
                    return
                }

                let cleanPhone = self.normalizedPhone()
                guard !self.phone.isEmpty, !cleanPhone.isEmpty else {
                    self.activeAlert = .success
                    return
                }

                // Verificación SMS opcional: si Firebase no la tiene configurada,
                // el registro sigue siendo válido y no se bloquea al usuario.
                self.firebaseService.startPhoneVerification(phoneNumber: cleanPhone) { verification in
                    switch verification {
                    case .success(let id):
                        self.verificationID = id
                        self.showOTP = true
                    case .failure:
                        self.activeAlert = .success
                    }
                }
            }
        }
    }

    private func finish(with outcome: RegisterOutcome) {
        self.onFinished(outcome)
        self.presentationMode.wrappedValue.dismiss()
    }

    private func normalizedPhone() -> String {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        if digits.hasPrefix("+") { return digits }
        if digits.isEmpty { return "" }
        return "+" + digits
    }
}

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var email: String = ""
    @State private var alertMessage: String?
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
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)

                    Button(action: {
                        sendReset()
                    }) {
                        HStack(spacing: 8) {
                            if firebaseService.isAuthBusy {
                                ProgressView().tint(.white)
                            }
                            Text("Enviar Correo")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.primary)
                        .cornerRadius(16)
                    }
                    .disabled(firebaseService.isAuthBusy)
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
            .alert(isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Alert(
                    title: Text(isSent ? "Correo Enviado" : "No se pudo enviar"),
                    message: Text(alertMessage ?? ""),
                    dismissButton: .default(Text("OK")) {
                        if isSent {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
    }

    private func sendReset() {
        firebaseService.sendPasswordReset(email: email) { result in
            switch result {
            case .success:
                self.isSent = true
                self.alertMessage = "Revisa tu bandeja de entrada para restablecer la contraseña."
            case .failure(let error):
                self.isSent = false
                self.alertMessage = self.firebaseService.authError ?? error.localizedDescription
            }
        }
    }
}

// MARK: - Keychain para acceso biométrico (Face ID / Touch ID)
public enum SessionKeychain {
    private static let service = "com.israviolink.ios.session"

    public struct Credential {
        public let email: String
        public let password: String
    }

    public static func save(email: String, password: String) {
        let payload = "\(email)\n\(password)".data(using: .utf8) ?? Data()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: email
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = payload
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(attributes as CFDictionary, nil)
    }

    public static func load() -> Credential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return Credential(email: String(parts[0]), password: String(parts[1]))
    }

    public static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}
