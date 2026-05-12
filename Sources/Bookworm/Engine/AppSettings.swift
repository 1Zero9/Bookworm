import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var geminiApiKey: String {
        didSet { UserDefaults.standard.set(geminiApiKey, forKey: "gemini.apiKey") }
    }
    @Published var geminiModel: String {
        didSet { UserDefaults.standard.set(geminiModel, forKey: "gemini.model") }
    }

    var hasApiKey: Bool { !geminiApiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    private init() {
        geminiApiKey = UserDefaults.standard.string(forKey: "gemini.apiKey") ?? ""
        geminiModel  = UserDefaults.standard.string(forKey: "gemini.model")  ?? "gemini-2.0-flash"
    }
}
