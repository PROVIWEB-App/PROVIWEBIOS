import SwiftUI

// MARK: - QAV & Web3 Wallet View (Wait24h & P-Wallet)
public struct QAVWalletView: View {
    @StateObject private var viewModel = WalletViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var walletService = Web3WalletService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isWithdrawPresented: Bool = false
    @State private var isCopiedAlert: Bool = false
    @State private var isSecurityPresented: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            theme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(theme.textPrimary)
                    }
                    Spacer()
                    Text("Monedero QAV")
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    Button(action: { isSecurityPresented = true }) {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundColor(walletService.isEmergencyFrozen ? AppColors.errorRed : AppColors.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.cardColor)
                
                // Emergency Frozen Banner if active
                if walletService.isEmergencyFrozen {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundColor(.white)
                        Text("Monedero Bloqueado por Emergencia")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppColors.errorRed)
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Main Balance Card
                        VStack(spacing: 16) {
                            Text("Saldo Total Acumulado")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text(String(format: "$%.2f USD", viewModel.walletBalance.balanceUSD))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 32) {
                                HStack(spacing: 6) {
                                    Image(systemName: "suit.diamond.fill")
                                        .foregroundColor(AppColors.gold)
                                    Text("\(viewModel.walletBalance.diamonds) Diamantes")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.white)
                                    Text("\(viewModel.walletBalance.referralCount) Referidos")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            Button(action: {
                                isWithdrawPresented = true
                            }) {
                                Text("Retirar Fondos")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primaryDark)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(20)
                            }
                        }
                        .padding(24)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(24)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // 24h Delayed Withdrawals Warning Card if any pending
                        let activePendings = walletService.pendingWithdrawals.filter { !$0.isCancelled && !$0.isExecuted }
                        if !activePendings.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "timer")
                                        .foregroundColor(AppColors.warningOrange)
                                    Text("Retiros en Periodo de Seguridad (Wait24h)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(theme.textPrimary)
                                }
                                
                                ForEach(activePendings) { pending in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(String(format: "$%.2f USD", pending.amountUSD))
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(theme.textPrimary)
                                            Text(pending.remainingTimeString)
                                                .font(.caption2)
                                                .foregroundColor(AppColors.warningOrange)
                                        }
                                        Spacer()
                                        Button("Cancelar") {
                                            walletService.cancelDelayedWithdrawal(recordId: pending.id)
                                        }
                                        .font(.caption2)
                                        .foregroundColor(AppColors.errorRed)
                                    }
                                    .padding(8)
                                    .background(theme.backgroundColor)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(16)
                            .background(theme.cardColor)
                            .cornerRadius(18)
                            .padding(.horizontal, 16)
                        }
                        
                        // Web3 Address & QR Code Card
                        VStack(spacing: 16) {
                            Text("Tu Dirección de Wallet Web3")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            if let qr = viewModel.qrCodeImage {
                                Image(uiImage: qr)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 170, height: 170)
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(16)
                            }
                            
                            HStack {
                                Text(walletService.walletAddress)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.textSecondary)
                                    .lineLimit(1)
                                
                                Button(action: {
                                    UIPasteboard.general.string = walletService.walletAddress
                                    isCopiedAlert = true
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                }) {
                                    Image(systemName: "doc.on.doc.fill")
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                            .padding(12)
                            .background(theme.backgroundColor)
                            .cornerRadius(12)
                        }
                        .padding(20)
                        .background(theme.cardColor)
                        .cornerRadius(20)
                        .padding(.horizontal, 16)
                        
                        // Security & Backup CTA Card
                        Button(action: { isSecurityPresented = true }) {
                            HStack(spacing: 14) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.title2)
                                    .foregroundColor(AppColors.primary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Seguridad & Copia BIP-39")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(theme.textPrimary)
                                    Text("Frase de 12 palabras, Face ID y retiros retardados 24h")
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(theme.textSecondary)
                            }
                            .padding(16)
                            .background(theme.cardColor)
                            .cornerRadius(18)
                        }
                        .padding(.horizontal, 16)
                        
                        // Practice Earning Notice
                        HStack(spacing: 14) {
                            Image(systemName: "stopwatch.fill")
                                .font(.title)
                                .foregroundColor(AppColors.gold)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gana practicando tu instrumento")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.textPrimary)
                                Text("Por cada 200 segundos de práctica activa en el Estudio de Práctica, recibes $1.00 USD de saldo.")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        .padding(16)
                        .background(theme.cardColor)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .sheet(isPresented: $isWithdrawPresented) {
            WithdrawRequestSheet()
        }
        .sheet(isPresented: $isSecurityPresented) {
            WalletSecurityView()
        }
        .alert(isPresented: $isCopiedAlert) {
            Alert(title: Text("Copiado"), message: Text("Dirección de monedero copiada al portapapeles."), dismissButton: .default(Text("OK")))
        }
    }
}

// MARK: - Withdraw Request Sheet
struct WithdrawRequestSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var walletService = Web3WalletService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var amountText: String = "50.00"
    @State private var paymentMethod: String = "Crypto"
    @State private var accountEmail: String = "0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7"
    @State private var alertMessage: String = ""
    @State private var isAlertPresented: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Monto a Retirar (USD)")) {
                        TextField("Monto USD", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    
                    Section(header: Text("Método de Pago")) {
                        Picker("Método", selection: $paymentMethod) {
                            Text("Crypto USDT / QAV (BEP20 / ERC20)").tag("Crypto")
                            Text("PayPal").tag("PayPal")
                            Text("Transferencia Bancaria").tag("Bank")
                        }
                        
                        TextField(paymentMethod == "Crypto" ? "Dirección 0x..." : "Correo / CLABE", text: $accountEmail)
                    }
                    
                    if paymentMethod == "Crypto" && walletService.is24hCooldownEnabled {
                        Section(header: Text("Información de Seguridad")) {
                            HStack {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundColor(AppColors.primary)
                                Text("Protección Activa de 24 Horas: Las direcciones no agregadas a tu lista blanca pasarán por un periodo de enfriamiento de 24h antes del envío final.")
                                    .font(.caption2)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    
                    Button(action: processWithdrawal) {
                        Text("Confirmar Retiro")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.primary)
                }
            }
            .navigationTitle("Solicitud de Retiro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .alert(isPresented: $isAlertPresented) {
                Alert(
                    title: Text("Estado del Retiro"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("Aceptar")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    private func processWithdrawal() {
        guard let amount = Double(amountText), amount > 0 else {
            alertMessage = "Por favor ingresa un monto válido."
            isAlertPresented = true
            return
        }
        
        let result = walletService.requestWithdrawal(amountUSD: amount, targetAddress: accountEmail)
        alertMessage = result.message
        isAlertPresented = true
    }
}
