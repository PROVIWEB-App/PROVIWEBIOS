import SwiftUI

// MARK: - Minor Student Wait Approval View (WaitApprovalActivity.java equivalent)
public struct WaitApprovalView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
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
                    
                    Image(systemName: "hourglass.badge.eye")
                        .font(.system(size: 52))
                        .foregroundColor(AppColors.primary)
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
                
                Spacer()
                
                Button(action: {
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
    }
}

// MARK: - Phone SMS OTP Verification View (GenerateOTPActivity.java equivalent)
public struct OTPVerificationView: View {
    let phoneNumber: String
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var otpCode: String = ""
    @State private var isVerifying: Bool = false
    
    public init(phoneNumber: String = "+52 55 1234 5678") {
        self.phoneNumber = phoneNumber
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
                        isVerifying = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        if isVerifying {
                            ProgressView()
                                .tint(.white)
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
                    
                    Spacer()
                }
            }
            .navigationTitle("Verificación OTP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
