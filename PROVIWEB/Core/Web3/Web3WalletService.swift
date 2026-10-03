import Foundation
import Security
import CoreImage.CIFilterBuiltins
import UIKit
import Combine

// MARK: - Web3 Keychain Secure Storage & QAV Token Service
public class Web3WalletService: ObservableObject {
    public static let shared = Web3WalletService()
    
    private let keychainService = "com.israviolink.app.wallet"
    private let privateKeyAccount = "qav_private_key"
    
    @Published public var walletAddress: String = "0x71C8364379963282b0bB39d91D3488734024982a"
    @Published public var isWalletConnected: Bool = true
    
    public init() {
        if getPrivateKeyFromKeychain() == nil {
            generateAndSaveNewWallet()
        }
    }
    
    public func generateAndSaveNewWallet() {
        let dummyPrivateKey = "d489b0d1e67290f92b7c61d56e07c80521e1a8a25c150c8f1f7d9834123abcde"
        savePrivateKeyToKeychain(dummyPrivateKey)
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
