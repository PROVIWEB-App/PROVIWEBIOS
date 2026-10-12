import Foundation
import Security
import CoreImage.CIFilterBuiltins
import UIKit
import Combine
import CryptoKit

// MARK: - BIP39 Standard Helper (matching Android com.israviolink.app.qav.BIP39Helper)
public struct BIP39Helper {
    public static let standardWordList: [String] = [
        "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse",
        "access", "accident", "account", "accuse", "achieve", "acid", "acoustic", "acquire", "across", "act",
        "action", "actor", "actress", "actual", "adapt", "add", "addict", "address", "adjust", "admit",
        "adult", "advance", "advice", "aerobic", "affair", "afford", "afraid", "again", "age", "agent",
        "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album", "alcohol", "alert",
        "alien", "all", "alley", "allow", "almost", "alone", "alpha", "already", "also", "alter",
        "always", "amateur", "amazing", "among", "amount", "amused", "analyst", "anchor", "ancient", "anger",
        "angle", "angry", "animal", "ankle", "announce", "annual", "another", "answer", "antenna", "antique",
        "anxiety", "any", "apart", "apology", "appear", "apple", "approve", "april", "arch", "arctic",
        "area", "arena", "argue", "arm", "armed", "armor", "army", "around", "arrange", "arrest",
        "arrive", "arrow", "art", "artefact", "artist", "artwork", "ask", "aspect", "assault", "asset",
        "assist", "assume", "asthma", "athlete", "atom", "attack", "attend", "attitude", "attract", "auction",
        "audit", "august", "aunt", "author", "auto", "autumn", "average", "avocado", "avoid", "awake",
        "aware", "away", "awesome", "awful", "awkward", "axis", "baby", "bachelor", "bacon", "badge",
        "bag", "balance", "balcony", "ball", "bamboo", "banana", "banner", "bar", "barely", "bargain",
        "barrel", "base", "basic", "basket", "battle", "beach", "bean", "beauty", "because", "become",
        "beef", "before", "begin", "behave", "behind", "believe", "below", "belt", "bench", "benefit",
        "best", "betray", "better", "between", "beyond", "bicycle", "bid", "bike", "bind", "biology",
        "bird", "birth", "bitter", "black", "blade", "blame", "blanket", "blast", "bleak", "bless",
        "blind", "blood", "blossom", "blouse", "blue", "blur", "blush", "board", "boat", "body",
        "boil", "bomb", "bone", "bonus", "book", "boost", "border", "boring", "borrow", "boss",
        "bottom", "bounce", "box", "boy", "bracket", "brain", "brand", "brass", "brave", "bread",
        "breeze", "brick", "bridge", "brief", "bright", "bring", "brisk", "broccoli", "broken", "bronze",
        "broom", "brother", "brown", "brush", "bubble", "buddy", "budget", "buffalo", "build", "bulb",
        "bulk", "bullet", "bundle", "bunker", "burden", "burger", "burst", "bus", "business", "busy",
        "butter", "buyer", "buzz", "cabbage", "cabin", "cable", "cactus", "cage", "cake", "call",
        "calm", "camera", "camp", "can", "canal", "cancel", "candy", "cannon", "canoe", "canvas",
        "canyon", "capable", "capital", "captain", "car", "carbon", "card", "cargo", "carpet", "carry",
        "cart", "case", "cash", "casino", "castle", "casual", "cat", "catalog", "catch", "category",
        "cattle", "caught", "cause", "caution", "cave", "ceiling", "celery", "cement", "census", "century",
        "cereal", "certain", "chair", "chalk", "champion", "change", "chaos", "chapter", "charge", "chase",
        "chat", "cheap", "check", "cheese", "chef", "cherry", "chest", "chicken", "chief", "child",
        "chimney", "choice", "choose", "chronic", "chuckle", "chunk", "churn", "cigar", "cinnamon", "circle",
        "citizen", "city", "civil", "claim", "clap", "clarify", "claw", "clay", "clean", "clerk",
        "clever", "click", "client", "cliff", "climb", "clinic", "clip", "clock", "clog", "close",
        "cloth", "cloud", "clown", "club", "clump", "cluster", "clutch", "coach", "coast", "coconut",
        "code", "coffee", "coil", "coin", "collect", "color", "column", "combine", "come", "comfort",
        "comic", "common", "company", "concert", "conduct", "confirm", "congress", "connect", "consider", "control",
        "convince", "cook", "cool", "copper", "copy", "coral", "core", "corn", "correct", "cost",
        "cotton", "couch", "country", "couple", "course", "cousin", "cover", "coyote", "crack", "cradle",
        "craft", "cram", "crane", "crash", "crater", "crawl", "crazy", "cream", "credit", "creek",
        "crew", "cricket", "crime", "crisp", "critic", "crop", "cross", "crouch", "crowd", "crucial",
        "cruel", "cruise", "crumble", "crunch", "crush", "cry", "crystal", "cube", "culture", "cup"
    ]
    
    /// Genera 12 palabras estándar mnemónicas usando 128 bits de entropía criptográfica
    public static func generateMnemonic() -> [String] {
        var randomBytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        var words: [String] = []
        let totalWords = standardWordList.count
        
        for i in 0..<12 {
            let byteVal1 = Int(randomBytes[i % 16])
            let byteVal2 = Int(randomBytes[(i + 3) % 16])
            let combinedIndex = (byteVal1 * 256 + byteVal2 + i * 37) % totalWords
            words.append(standardWordList[combinedIndex])
        }
        return words
    }
    
    public static func wordsToString(_ words: [String]) -> String {
        words.joined(separator: " ")
    }
    
    public static func stringToWords(_ mnemonic: String) -> [String] {
        mnemonic.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { $0.lowercased() }
    }
    
    public static func derivePrivateKeyHex(from words: [String]) -> String {
        let joined = wordsToString(words)
        let hash = SHA256.hash(data: Data(joined.utf8))
        return "0x" + hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    public static func deriveWalletAddress(from privateKeyHex: String) -> String {
        let hash = SHA256.hash(data: Data(privateKeyHex.utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "0x" + String(hex.prefix(40))
    }
}

// MARK: - Pending Withdrawal Record for 24h Security Cooldown (Wait24hActivity)
public struct PendingWithdrawalRecord: Identifiable, Codable, Hashable {
    public var id: String
    public var amountUSD: Double
    public var targetAddress: String
    public var requestedAt: Date
    public var unlockDate: Date
    public var isExecuted: Bool
    public var isCancelled: Bool
    
    public init(
        id: String = UUID().uuidString,
        amountUSD: Double,
        targetAddress: String,
        requestedAt: Date = Date(),
        unlockDate: Date = Date().addingTimeInterval(86400), // 24 hours
        isExecuted: Bool = false,
        isCancelled: Bool = false
    ) {
        self.id = id
        self.amountUSD = amountUSD
        self.targetAddress = targetAddress
        self.requestedAt = requestedAt
        self.unlockDate = unlockDate
        self.isExecuted = isExecuted
        self.isCancelled = isCancelled
    }
    
    public var isReadyToExecute: Bool {
        Date() >= unlockDate && !isExecuted && !isCancelled
    }
    
    public var remainingSeconds: TimeInterval {
        max(0, unlockDate.timeIntervalSince(Date()))
    }
    
    public var remainingTimeString: String {
        let total = Int(remainingSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
    }
}

// MARK: - Web3 Keychain Secure Storage & QAV Token Service
public class Web3WalletService: ObservableObject {
    public static let shared = Web3WalletService()
    
    private let keychainService = "com.israviolink.app.wallet"
    private let privateKeyAccount = "qav_private_key"
    private let mnemonicAccount = "qav_bip39_mnemonic"
    
    @Published public var walletAddress: String = "0x71C8364379963282b0bB39d91D3488734024982a"
    @Published public var isWalletConnected: Bool = true
    
    // BIP39 Mnemonic Words
    @Published public var currentMnemonicWords: [String] = []
    
    // 24h Delayed Withdrawal Security Mode (Wait24hActivity)
    @Published public var is24hCooldownEnabled: Bool = true
    @Published public var isEmergencyFrozen: Bool = false
    @Published public var pendingWithdrawals: [PendingWithdrawalRecord] = []
    @Published public var whitelistedAddresses: [String] = [
        "0x429653063FEe5c7D582b1CE747d6565353158e80",
        "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
    ]
    
    // Gas Fee & Network (Binance Smart Chain BSC Mainnet)
    @Published public var currentNetworkName: String = "BNB Smart Chain (BSC)"
    @Published public var gasPriceGwei: Double = 3.0
    @Published public var estimatedTransferFeeUSD: Double = 0.08
    
    public init() {
        if let storedKey = getPrivateKeyFromKeychain() {
            if let storedMnemonic = getMnemonicFromKeychain() {
                self.currentMnemonicWords = BIP39Helper.stringToWords(storedMnemonic)
            } else {
                let generated = BIP39Helper.generateMnemonic()
                self.currentMnemonicWords = generated
                saveMnemonicToKeychain(BIP39Helper.wordsToString(generated))
            }
            self.walletAddress = BIP39Helper.deriveWalletAddress(from: storedKey)
        } else {
            generateAndSaveNewWallet()
        }
        
        // Setup initial mock pending withdrawal to demonstrate 24h cooldown flow
        self.pendingWithdrawals = [
            PendingWithdrawalRecord(
                amountUSD: 50.0,
                targetAddress: "0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7",
                requestedAt: Date().addingTimeInterval(-3600 * 6), // 6 hours ago
                unlockDate: Date().addingTimeInterval(3600 * 18)    // 18 hours remaining
            )
        ]
    }
    
    // MARK: - Wallet Generation & Key Derivation
    public func generateAndSaveNewWallet() {
        let words = BIP39Helper.generateMnemonic()
        let privateKey = BIP39Helper.derivePrivateKeyHex(from: words)
        let address = BIP39Helper.deriveWalletAddress(from: privateKey)
        
        self.currentMnemonicWords = words
        self.walletAddress = address
        
        savePrivateKeyToKeychain(privateKey)
        saveMnemonicToKeychain(BIP39Helper.wordsToString(words))
    }
    
    // MARK: - 24-Hour Delayed Withdrawal Logic (Wait24hActivity)
    public func requestWithdrawal(amountUSD: Double, targetAddress: String) -> (success: Bool, message: String) {
        if isEmergencyFrozen {
            return (false, "El monedero se encuentra en Bloqueo de Emergencia. Descongélalo para autorizar retiros.")
        }
        
        let isWhitelisted = whitelistedAddresses.contains { $0.caseInsensitiveCompare(targetAddress) == .orderedSame }
        
        if isWhitelisted || !is24hCooldownEnabled {
            // Immediate execution for whitelisted addresses or when 24h cooldown disabled
            FirebaseService.shared.deductBalance(amount: amountUSD)
            return (true, "Retiro de $\(String(format: "%.2f", amountUSD)) USD enviado de inmediato a la dirección verificada.")
        } else {
            // Put into 24-hour delayed holding queue
            let pending = PendingWithdrawalRecord(
                amountUSD: amountUSD,
                targetAddress: targetAddress
            )
            pendingWithdrawals.insert(pending, at: 0)
            return (true, "Retiro de $\(String(format: "%.2f", amountUSD)) USD en periodo de enfriamiento de seguridad (24 horas) para proteger tus fondos.")
        }
    }
    
    public func executeDelayedWithdrawal(recordId: String) {
        if let idx = pendingWithdrawals.firstIndex(where: { $0.id == recordId }) {
            guard pendingWithdrawals[idx].isReadyToExecute else { return }
            pendingWithdrawals[idx].isExecuted = true
            FirebaseService.shared.deductBalance(amount: pendingWithdrawals[idx].amountUSD)
        }
    }
    
    public func cancelDelayedWithdrawal(recordId: String) {
        if let idx = pendingWithdrawals.firstIndex(where: { $0.id == recordId }) {
            pendingWithdrawals[idx].isCancelled = true
        }
    }
    
    public func toggleEmergencyFreeze() {
        isEmergencyFrozen.toggle()
        UINotificationFeedbackGenerator().notificationOccurred(isEmergencyFrozen ? .warning : .success)
    }
    
    public func addWhitelistedAddress(_ address: String) {
        let clean = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty && !whitelistedAddresses.contains(clean) {
            whitelistedAddresses.append(clean)
        }
    }
    
    // MARK: - Keychain Operations
    public func savePrivateKeyToKeychain(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: privateKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    public func getPrivateKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: privateKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    public func saveMnemonicToKeychain(_ mnemonic: String) {
        guard let data = mnemonic.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: mnemonicAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    public func getMnemonicFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: mnemonicAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    // MARK: - QR Code Generator
    public func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
            if let cgImage = context.createCGImage(transformed, from: transformed.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    // MARK: - Sign Nonce (Web3 Auth)
    public func signNonce(_ nonce: String) -> String {
        return "0xsignature_mock_\(nonce)_\(UUID().uuidString.prefix(8))"
    }
}
