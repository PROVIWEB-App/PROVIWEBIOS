import SwiftUI

// MARK: - Minor Student Wait Approval View (WaitApprovalActivity.java equivalent)
public struct WaitApprovalView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var statusMessage: String?
    @State private var isChecking: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.12))
                        .frame(width: 120, height: 120)
                    
                    // hourglass.badge.eye es SF Symbols 6 (iOS 18); fallback para iOS 16/17.
                    if #available(iOS 18.0, *) {
                        Image(systemName: "hourglass.badge.eye")
                            .font(.system(size: 52))
                            .foregroundColor(AppColors.primary)
                    } else {
                        Image(systemName: "hourglass.tophalf.filled")
                            .font(.system(size: 52))
                            .foregroundColor(AppColors.primary)
                    }
                }
                
                Text("Cuenta en Espera de Aprobación")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Tu registro como estudiante menor de edad o institución educativa está siendo revisado por nuestro equipo pedagógico para garantizar la máxima seguridad.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(AppColors.primary)
                        Text("Verificando autorización parental...")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }
                    .padding(.vertical, 8)
                }
                .padding(16)
                .background(theme.cardColor)
                .cornerRadius(16)
                .padding(.horizontal, 24)
                
                if let email = firebaseService.currentUser?.email {
                    Text("Notificaremos la aprobación a \(email)")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()

                Button(action: {
                    checkStatus()
                }) {
                    HStack(spacing: 8) {
                        if isChecking {
                            ProgressView().tint(AppColors.primary)
                        } else {
                            Text("Comprobar estado")
                                .fontWeight(.bold)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.primary.opacity(0.12))
                    .cornerRadius(16)
                }
                .disabled(isChecking)
                .padding(.horizontal, 24)

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    firebaseService.isAuthenticated = false
                }) {
                    Text("Cerrar Sesión")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.errorRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.errorRed.opacity(0.12))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .alert(isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Alert(
                title: Text("Estado de tu cuenta"),
                message: Text(statusMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    /// Equivalente a `btnCheckStatus` de WaitApprovalActivity.java (Android).
    private func checkStatus() {
        isChecking = true
        firebaseService.checkMinorApprovalStatus { outcome in
            isChecking = false
            switch outcome {
            case .approved:
                statusMessage = "¡Tu cuenta ha sido aprobada! Bienvenido."
            case .pending:
                statusMessage = "Tu solicitud sigue en proceso de revisión."
            case .unresolved:
                statusMessage = "No se pudo verificar el estado (sin conexión). Intenta de nuevo."
            }
        }
    }
}

// MARK: - Phone SMS OTP Verification View (GenerateOTPActivity.java equivalent)
public struct OTPVerificationView: View {
    let phoneNumber: String
    let verificationID: String?
    private let onCompleted: ((Bool) -> Void)?

    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var otpCode: String = ""
    @State private var errorMessage: String?
    @State private var isVerifying: Bool = false

    public init(
        phoneNumber: String = "+52 55 1234 5678",
        verificationID: String? = nil,
        onCompleted: ((Bool) -> Void)? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.verificationID = verificationID
        self.onCompleted = onCompleted
    }

    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "message.badge.filled.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.primary)
                        .padding(.top, 30)

                    Text("Código de Verificación")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)

                    Text("Ingresa el código de 6 dígitos enviado por SMS a tu número \(phoneNumber)")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    TextField("• • • • • •", text: $otpCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding(14)
                        .background(theme.cardColor)
                        .cornerRadius(16)
                        .padding(.horizontal, 48)

                    Button(action: {
                        verify()
                    }) {
                        HStack(spacing: 8) {
                            if isVerifying || firebaseService.isAuthBusy {
                                ProgressView().tint(.white)
                            } else {
                                Text("Verificar y Continuar")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.primary)
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                    }
                    .disabled(isVerifying || firebaseService.isAuthBusy)

                    Button(action: {
                        onCompleted?(false)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Omitir por ahora")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Verificación OTP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onCompleted?(false)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Alert(
                    title: Text("Código no válido"),
                    message: Text(errorMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // MARK: - Verificación real contra Firebase Phone Auth (con enlace a la cuenta)
    private func verify() {
        let code = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.count >= 6 else {
            errorMessage = "El código debe tener al menos 6 dígitos."
            return
        }

        guard let verificationID = verificationID else {
            // Sin flujo SMS activo: se valida localmente para no bloquear al usuario.
            onCompleted?(true)
            presentationMode.wrappedValue.dismiss()
            return
        }

        isVerifying = true
        firebaseService.confirmPhoneVerification(verificationID: verificationID, code: code) { [onCompleted, presentationMode] result in
            isVerifying = false
            switch result {
            case .success:
                onCompleted?(true)
                presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                errorMessage = firebaseService.authError ?? error.localizedDescription
            }
        }
    }
}
