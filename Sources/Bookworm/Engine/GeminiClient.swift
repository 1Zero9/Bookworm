import Foundation

enum GeminiError: Error, LocalizedError {
    case noApiKey
    case httpError(Int, String)
    case noContent
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noApiKey:               return "No Gemini API key set — open Settings to add yours."
        case .httpError(let c, let m): return "Gemini API error \(c): \(m)"
        case .noContent:              return "Gemini returned an empty response."
        case .decodingFailed(let m):  return "Could not parse Gemini response: \(m)"
        }
    }
}

final class GeminiClient {
    static let shared = GeminiClient()
    private let base = "https://generativelanguage.googleapis.com/v1beta/models"

    func generate(prompt: String) async throws -> String {
        let s = AppSettings.shared
        guard s.hasApiKey else { throw GeminiError.noApiKey }

        let urlStr = "\(base)/\(s.geminiModel):generateContent?key=\(s.geminiApiKey)"
        guard let url = URL(string: urlStr) else {
            throw GeminiError.decodingFailed("Invalid URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = String(data: data, encoding: .utf8) ?? "No details"
            throw GeminiError.httpError(http.statusCode, msg)
        }

        // Parse Gemini envelope
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text else {
            throw GeminiError.noContent
        }
        return text
    }
}
