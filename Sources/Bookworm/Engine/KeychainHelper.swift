import Foundation
import Security

/// Thread-safe helper utility to interact with the secure macOS Keychain.
final class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let service = "com.bookworm.app.apikey"
    private let account = "gemini.apiKey"
    private let lock = NSLock()
    
    private init() {}
    
    /// Encrypts and saves an API key string securely inside the macOS Keychain.
    func save(_ value: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete any existing item first to prevent duplicate item errors
        SecItemDelete(query as CFDictionary)
        
        // Add the new encrypted item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[KeychainHelper] Save failed with OSStatus code: \(status)")
        }
    }
    
    /// Retrieves and decrypts the saved API key securely from the macOS Keychain.
    func read() -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
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
    
    /// Securely wipes the API key from the Keychain.
    func delete() {
        lock.lock()
        defer { lock.unlock() }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
