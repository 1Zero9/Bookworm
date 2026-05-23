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
    
    /// Safely strips markdown code fences (e.g., ```json and ```) and trims whitespace from a raw AI string response.
    static func cleanJsonString(_ raw: String) -> String {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        if clean.hasPrefix("```")     { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```")     { clean = String(clean.dropLast(3)) }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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

    func summarizeChapter(text: String, title: String) async throws -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.isEmpty {
            return "An empty chapter titled '\(title)'."
        }
        
        let prompt = """
        You are an expert editorial assistant. Distill the following chapter prose (titled "\(title)") into a single, punchy, elegant sentence summary/synopsis under 25 words.
        
        Return the result as a JSON object with a single key "synopsis".
        
        Chapter Title: \(title)
        Chapter Content:
        \(cleanText)
        """
        
        let rawJson = try await generate(prompt: prompt)
        let cleanJson = Self.cleanJsonString(rawJson)
        
        struct SummaryPayload: Decodable {
            let synopsis: String
        }
        
        guard let data = cleanJson.data(using: .utf8) else {
            throw GeminiError.decodingFailed("Could not encode response to UTF-8")
        }
        let decoded = try JSONDecoder().decode(SummaryPayload.self, from: data)
        return decoded.synopsis
    }
}
