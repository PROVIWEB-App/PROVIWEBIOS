import SwiftUI

// MARK: - QAV & Web3 Wallet View
public struct QAVWalletView: View {
    @StateObject private var viewModel = WalletViewModel()
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isWithdrawPresented: Bool = false
    @State private var isDiamondWithdrawPresented: Bool = false
    @State private var isCopiedAlert: Bool = false

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
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(AppColors.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.cardColor)
                
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
                            
                            VStack(spacing: 10) {
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
                                
                                // Retiro de diamantes (DiamondWithdrawView)
                                Button(action: {
                                    isDiamondWithdrawPresented = true
                                }) {
                                    Text("Retirar Diamantes 💎")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.white, lineWidth: 1.5)
                                        )
                                        .cornerRadius(20)
                                }
                            }
                            .sheet(isPresented: $isDiamondWithdrawPresented) {
                                DiamondWithdrawView()
                            }
                        }
                        .padding(24)
                        .background(AppColors.primaryGradient)
                        .cornerRadius(24)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
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
                                    .frame(width: 180, height: 180)
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(16)
                            }
                            
                            HStack {
                                Text(viewModel.walletBalance.walletAddress ?? "0x71C...4982a")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.textSecondary)
                                    .lineLimit(1)
                                
                                Button(action: {
                                    UIPasteboard.general.string = viewModel.walletBalance.walletAddress
                                    isCopiedAlert = true
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
                                Text("Por cada 200 segundos de práctica activa en la app, recibes $1.00 USD de saldo.")
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
        .alert(isPresented: $isCopiedAlert) {
            Alert(title: Text("Copiado"), message: Text("Dirección de monedero copiada al portapapeles."), dismissButton: .default(Text("OK")))
        }
    }
}

// MARK: - Withdraw Request Sheet
struct WithdrawRequestSheet: View {
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var amountText: String = "50.00"
    @State private var paymentMethod: String = "PayPal"
    @State private var accountEmail: String = ""
    @State private var isSuccess: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Monto a Retirar")) {
                        TextField("Monto USD", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    
                    Section(header: Text("Método de Pago")) {
                        Picker("Método", selection: $paymentMethod) {
                            Text("PayPal").tag("PayPal")
                            Text("Transferencia Bancaria (CLABE / IBAN)").tag("Bank")
                            Text("Crypto USDT / QAV (ERC20)").tag("Crypto")
                        }
                        
                        TextField("Correo o Cuenta de Destino", text: $accountEmail)
                    }
                    
                    Button(action: {
                        isSuccess = true
                    }) {
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
            .alert(isPresented: $isSuccess) {
                Alert(
                    title: Text("Solicitud Registrada"),
                    message: Text("Tu retiro ha sido enviado a revisión. Recibirás tus fondos en 24 a 48 horas."),
                    dismissButton: .default(Text("Aceptar")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
}
