import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var geminiApiKey: String {
        didSet { KeychainHelper.shared.save(geminiApiKey) }
    }
    @Published var geminiModel: String {
        didSet { UserDefaults.standard.set(geminiModel, forKey: "gemini.model") }
    }

    var hasApiKey: Bool { !geminiApiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    private init() {
        // Safe one-time migration: check if UserDefaults has a key, migrate to Keychain, then wipe it.
        let oldKey = UserDefaults.standard.string(forKey: "gemini.apiKey") ?? ""
        if !oldKey.isEmpty {
            KeychainHelper.shared.save(oldKey)
            UserDefaults.standard.removeObject(forKey: "gemini.apiKey")
        }
        
        geminiApiKey = KeychainHelper.shared.read() ?? ""
        geminiModel  = UserDefaults.standard.string(forKey: "gemini.model")  ?? "gemini-2.0-flash"
    }
}
