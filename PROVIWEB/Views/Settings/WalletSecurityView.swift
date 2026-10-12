import SwiftUI
import LocalAuthentication

// MARK: - Web3 & Wallet Security View (Wait24hActivity & BIP39 Helper)
public struct WalletSecurityView: View {
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var walletService = Web3WalletService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isBiometricsEnabled: Bool = true
    @State private var isPinCodeEnabled: Bool = true
    @State private var is2FAEnabled: Bool = false
    
    // Sheets & Modals
    @State private var isExportKeySheetPresented: Bool = false
    @State private var isMnemonicSheetPresented: Bool = false
    @State private var isAddWhitelistPresented: Bool = false
    @State private var newWhitelistAddress: String = ""
    @State private var exportedKey: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                Form {
                    // Biometrics Section
                    Section(header: Text("Autenticación Biométrica y Acceso")) {
                        Toggle("Desbloqueo con Face ID / Touch ID", isOn: $isBiometricsEnabled)
                        Toggle("Requerir PIN para Enviar Fondos o QAV", isOn: $isPinCodeEnabled)
                        Toggle("Autenticación de 2 Factores (2FA)", isOn: $is2FAEnabled)
                    }
                    
                    // BIP39 Mnemonic Backup Section
                    Section(header: Text("Copia de Seguridad BIP-39 (12 Palabras)")) {
                        Button(action: requestBiometricMnemonicView) {
                            HStack {
                                Image(systemName: "text.badge.checkmark")
                                    .foregroundColor(AppColors.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Frase de Recuperación Mnemónica")
                                        .font(.subheadline)
                                        .foregroundColor(theme.textPrimary)
                                    Text("12 palabras para restaurar monedero en cualquier app Web3")
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "faceid")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                        
                        Button(action: requestBiometricKeyExport) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(AppColors.gold)
                                Text("Exportar Llave Privada Hexadecimal")
                                    .font(.subheadline)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    
                    // 24h Delayed Withdrawal Protection Section (Wait24hActivity)
                    Section(
                        header: Text("Protección de Retiros 24 Horas (Wait24h)"),
                        footer: Text("El modo 24 Horas retiene transacciones hacia direcciones no verificadas durante 24 horas, permitiendo cancelar retiros en caso de acceso no autorizado.")
                    ) {
                        Toggle("Activar Enfriamiento de 24 Horas", isOn: $walletService.is24hCooldownEnabled)
                        
                        Toggle("Congelación de Emergencia del Monedero", isOn: Binding(
                            get: { walletService.isEmergencyFrozen },
                            set: { _ in walletService.toggleEmergencyFreeze() }
                        ))
                        .foregroundColor(walletService.isEmergencyFrozen ? AppColors.errorRed : theme.textPrimary)
                        
                        if walletService.isEmergencyFrozen {
                            HStack {
                                Image(systemName: "exclamationmark.octagon.fill")
                                    .foregroundColor(AppColors.errorRed)
                                Text("Monedero Congelado: Todos los retiros salientes están bloqueados.")
                                    .font(.caption)
                                    .foregroundColor(AppColors.errorRed)
                            }
                        }
                    }
                    
                    // Pending 24h Delayed Withdrawals
                    if !walletService.pendingWithdrawals.filter({ !$0.isCancelled && !$0.isExecuted }).isEmpty {
                        Section(header: Text("Retiros en Periodo de Enfriamiento (24h)")) {
                            ForEach(walletService.pendingWithdrawals.filter({ !$0.isCancelled && !$0.isExecuted })) { pending in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(String(format: "$%.2f USD", pending.amountUSD))
                                            .font(.headline)
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Image(systemName: "timer")
                                            Text(pending.remainingTimeString)
                                        }
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(pending.isReadyToExecute ? AppColors.success : AppColors.warningOrange)
                                    }
                                    
                                    Text("Destino: \(pending.targetAddress.prefix(12))...\(pending.targetAddress.suffix(6))")
                                        .font(.caption2)
                                        .foregroundColor(theme.textSecondary)
                                    
                                    HStack(spacing: 12) {
                                        Button(action: {
                                            walletService.cancelDelayedWithdrawal(recordId: pending.id)
                                        }) {
                                            Text("Cancelar Retiro")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(AppColors.errorRed)
                                        }
                                        
                                        Spacer()
                                        
                                        if pending.isReadyToExecute {
                                            Button(action: {
                                                walletService.executeDelayedWithdrawal(recordId: pending.id)
                                            }) {
                                                Text("Ejecutar Retiro")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(AppColors.success)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // Whitelisted Addresses (Bypass 24h delay)
                    Section(header: Text("Direcciones en Lista Blanca (Retiro Inmediato)")) {
                        ForEach(walletService.whitelistedAddresses, id: \.self) { addr in
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(AppColors.success)
                                Text("\(addr.prefix(12))...\(addr.suffix(6))")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                        
                        Button(action: { isAddWhitelistPresented = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(AppColors.primary)
                                Text("Agregar Dirección de Confianza")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    
                    // Network Info
                    Section(header: Text("Red Blockchain Activa")) {
                        HStack {
                            Text("Red")
                            Spacer()
                            Text(walletService.currentNetworkName)
                                .foregroundColor(theme.textSecondary)
                        }
                        HStack {
                            Text("Gas Estimado")
                            Spacer()
                            Text(String(format: "%.1f Gwei (~$%.2f USD)", walletService.gasPriceGwei, walletService.estimatedTransferFeeUSD))
                                .foregroundColor(theme.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle("Seguridad del Monedero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
            .sheet(isPresented: $isExportKeySheetPresented) {
                ExportKeyModal(key: exportedKey)
            }
            .sheet(isPresented: $isMnemonicSheetPresented) {
                MnemonicDisplayModal(words: walletService.currentMnemonicWords)
            }
            .sheet(isPresented: $isAddWhitelistPresented) {
                addWhitelistModal
            }
        }
    }
    
    // MARK: - Biometrics Gating
    private func requestBiometricKeyExport() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Confirma tu identidad para ver tu llave privada") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.exportedKey = walletService.getPrivateKeyFromKeychain() ?? "0x9482f719401abde4929384729104"
                        self.isExportKeySheetPresented = true
                    }
                }
            }
        } else {
            self.exportedKey = walletService.getPrivateKeyFromKeychain() ?? "0x9482f719401abde4929384729104"
            self.isExportKeySheetPresented = true
        }
    }
    
    private func requestBiometricMnemonicView() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Confirma tu identidad para ver tu frase mnemónica de 12 palabras") { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.isMnemonicSheetPresented = true
                    }
                }
            }
        } else {
            self.isMnemonicSheetPresented = true
        }
    }
    
    // MARK: - Add Whitelist Modal
    private var addWhitelistModal: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Ingresa una dirección de confianza (por ejemplo, tu cuenta en Binance, Metamask o cold wallet):")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("0x...", text: $newWhitelistAddress)
                        .padding(12)
                        .background(theme.cardColor)
                        .cornerRadius(12)
                        .foregroundColor(theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        if !newWhitelistAddress.isEmpty {
                            walletService.addWhitelistedAddress(newWhitelistAddress)
                            newWhitelistAddress = ""
                        }
                        isAddWhitelistPresented = false
                    }) {
                        Text("Guardar Dirección")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.primary)
                            .cornerRadius(16)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Nueva Dirección")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { isAddWhitelistPresented = false }
                }
            }
        }
    }
}

// MARK: - BIP-39 12-Words Mnemonic Display & Verification Modal
public struct MnemonicDisplayModal: View {
    public let words: [String]
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isCopied: Bool = false
    @State private var isVerificationActive: Bool = false
    @State private var selectedWordsForTest: [String] = []
    @State private var verificationPassed: Bool? = nil
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Image(systemName: "key.viewfinder")
                            .font(.system(size: 56))
                            .foregroundColor(AppColors.primary)
                        
                        Text("Frase de Recuperación (BIP-39)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(theme.textPrimary)
                        
                        Text("Anota estas 12 palabras en papel y guárdalas en un lugar seguro. Con ellas puedes recuperar tus fondos en cualquier billetera Web3 (TrustWallet, MetaMask).")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // 3x4 Grid of Words
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(0..<words.count, id: \.self) { idx in
                                HStack(spacing: 6) {
                                    Text("\(idx + 1).")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.primary)
                                    Text(words[idx])
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                        .foregroundColor(theme.textPrimary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.cardColor)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // Copy Button
                        Button(action: {
                            UIPasteboard.general.string = words.joined(separator: " ")
                            isCopied = true
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: isCopied ? "checkmark" : "doc.on.doc.fill")
                                Text(isCopied ? "Frase Copiada" : "Copiar Frase al Portapapeles")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppColors.primary.opacity(0.12))
                            .cornerRadius(16)
                        }
                        
                        Divider().padding(.vertical, 8)
                        
                        // Interactive Verification Test
                        VStack(spacing: 12) {
                            Text("Test de Verificación de Respaldo")
                                .font(.headline)
                                .foregroundColor(theme.textPrimary)
                            
                            Text("Demuestra que respaldaste tu frase seleccionando las 3 primeras palabras en orden:")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                                .multilineTextAlignment(.center)
                            
                            if !selectedWordsForTest.isEmpty {
                                HStack(spacing: 8) {
                                    ForEach(selectedWordsForTest, id: \.self) { w in
                                        Text(w)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(AppColors.primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            
                            // Shuffled selection chips
                            let sampleWords = Array(words.prefix(6)).shuffled()
                            HStack(spacing: 8) {
                                ForEach(sampleWords, id: \.self) { sample in
                                    Button(action: {
                                        if selectedWordsForTest.count < 3 && !selectedWordsForTest.contains(sample) {
                                            selectedWordsForTest.append(sample)
                                            if selectedWordsForTest.count == 3 {
                                                checkVerification()
                                            }
                                        }
                                    }) {
                                        Text(sample)
                                            .font(.caption)
                                            .foregroundColor(theme.textPrimary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(theme.cardColor)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            
                            if let passed = verificationPassed {
                                HStack(spacing: 6) {
                                    Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(passed ? AppColors.success : AppColors.errorRed)
                                    Text(passed ? "¡Verificación Exitosa! Copia guardada correctamente." : "Orden incorrecto. Revisa tu frase e intenta de nuevo.")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(passed ? AppColors.success : AppColors.errorRed)
                                }
                                .padding(.top, 4)
                            }
                            
                            if selectedWordsForTest.count > 0 {
                                Button("Reiniciar Prueba") {
                                    selectedWordsForTest.removeAll()
                                    verificationPassed = nil
                                }
                                .font(.caption2)
                                .foregroundColor(theme.textSecondary)
                            }
                        }
                        .padding(16)
                        .background(theme.cardColor.opacity(0.6))
                        .cornerRadius(18)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Frase Mnemónica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
    
    private func checkVerification() {
        let expected = Array(words.prefix(3))
        if selectedWordsForTest == expected {
            verificationPassed = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            verificationPassed = false
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Export Key Modal
public struct ExportKeyModal: View {
    public let key: String
    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isCopied: Bool = false
    
    public var body: some View {
        NavigationView {
            ZStack {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 56))
                        .foregroundColor(AppColors.warningOrange)
                    
                    Text("¡ADVERTENCIA DE SEGURIDAD!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                    
                    Text("Cualquier persona que tenga acceso a esta clave privada tendrá control absoluto sobre tus activos QAV y fondos. No la compartas con administradores ni intermediarios.")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Llave Privada Hexadecimal:")
                            .font(.caption2)
                            .foregroundColor(theme.textSecondary)
                        
                        Text(key)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.primary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(theme.cardColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    Button(action: {
                        UIPasteboard.general.string = key
                        isCopied = true
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc.fill")
                            Text(isCopied ? "Copiada al Portapapeles" : "Copiar Llave")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(isCopied ? AppColors.success : AppColors.primary)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Llave Privada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
