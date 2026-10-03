import SwiftUI

// MARK: - Diamond Conversion & Payout Request View (DiamondWithdraw.java equivalent)
public struct DiamondWithdrawView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var firebaseService = FirebaseService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var diamondsToConvert: Double = 200
    @State private var paymentMethod: String = "PayPal"
    @State private var accountDetails: String = ""
    @State private var isSuccessAlert: Bool = false
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Diamond Balance Hero
                        VStack(spacing: 12) {
                            Text("💎")
                                .font(.system(size: 48))
                            
                            Text("Tus Diamantes: \(firebaseService.walletBalance.diamonds)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("100 Diamantes = $1.00 USD de saldo canjeable.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.purple, Color.indigo]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // Conversion Form
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Canjear Diamantes por Saldo USD")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Cantidad a Canjear: \(Int(diamondsToConvert)) Diamantes = $\(String(format: "%.2f", diamondsToConvert / 100.0)) USD")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                
                                Slider(value: $diamondsToConvert, in: 100...Double(max(100, firebaseService.walletBalance.diamonds)), step: 50)
                                    .accentColor(AppColors.primary)
                            }
                            
                            Picker("Método de Pago", selection: $paymentMethod) {
                                Text("PayPal").tag("PayPal")
                                Text("Transferencia Bancaria").tag("Banco")
                                Text("Cripto USDT / QAV").tag("Crypto")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            TextField(paymentMethod == "PayPal" ? "Correo de PayPal" : (paymentMethod == "Banco" ? "CLABE Interbancaria / IBAN" : "Dirección Wallet USDT ERC-20"), text: $accountDetails)
                                .padding(12)
                                .background(theme.backgroundColor)
                                .cornerRadius(12)
                                .foregroundColor(theme.textPrimary)
                            
                            Button(action: {
                                isSuccessAlert = true
                            }) {
                                Text("Solicitar Retiro")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppColors.primary)
                                    .cornerRadius(14)
                            }
                        }
                        .padding(18)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Canje de Diamantes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isSuccessAlert) {
                Alert(title: Text("Solicitud de Pago"), message: Text("Tu retiro ha sido registrado y se procesará en un plazo de 24 a 48 horas."), dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                })
            }
        }
    }
}
