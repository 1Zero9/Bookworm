import Foundation
import AppKit

final class ImagenClient {
    static let shared = ImagenClient()
    private init() {}
    
    /// Sends a request to Google's Imagen 3 API to generate an image from a detailed text prompt.
    func generateImage(prompt: String, aspectRatio: String = "1:1") async throws -> NSImage {
        let settings = AppSettings.shared
        guard settings.hasApiKey else { throw GeminiError.noApiKey }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=\(settings.geminiApiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.decodingFailed("Invalid URL string for Imagen 3 endpoint.")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "instances": [
                ["prompt": prompt]
            ],
            "parameters": [
                "sampleCount": 1,
                "aspectRatio": aspectRatio,
                "outputMimeType": "image/png"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = String(data: data, encoding: .utf8) ?? "No response details"
            throw GeminiError.httpError(http.statusCode, msg)
        }
        
        struct PredictionsResponse: Decodable {
            struct Prediction: Decodable {
                let bytesBase64Encoded: String
            }
            let predictions: [Prediction]
        }
        
        let decoded = try JSONDecoder().decode(PredictionsResponse.self, from: data)
        guard let base64 = decoded.predictions.first?.bytesBase64Encoded,
              let imgData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let image = NSImage(data: imgData) else {
            throw GeminiError.noContent
        }
        
        return image
    }
    
    /// Leverages a fast Gemini model call to convert raw story passage narrative into a structured artistic prompt.
    func distillVisualPrompt(text: String, genre: String, styleNotes: String) async throws -> String {
        let settings = AppSettings.shared
        guard settings.hasApiKey else { throw GeminiError.noApiKey }
        
        let prompt = """
        You are an expert art director. Convert the following prose passage from a novel into a singular, highly descriptive, and evocative visual prompt for an image generator (like Imagen 3).
        
        The prompt must capture the core characters, setting, emotional tone, and texture described in the passage.
        Avoid buzzwords like "photorealistic", "hyperrealistic", "trending on artstation". Instead, use specific artistic styles (e.g., "watercolor and ink", "dramatic low-key oil painting", "moody charcoal sketching"), lighting details (e.g. "chiaroscuro", "golden hour light"), and descriptive verbs.
        
        ## CORE NOVEL METRICS
        Genre: \(genre)
        Style/Tone Notes: \(styleNotes)
        
        ## PASSAGE EXCERPT
        \(text.prefix(2000))
        
        ## YOUR TASK
        Return ONLY a valid JSON object containing the visual prompt under the key "visualPrompt". No markdown code fences, no extra commentary text.
        
        JSON Format:
        {
          "visualPrompt": "A dramatic oil painting of..."
        }
        """
        
        let jsonStr = try await GeminiClient.shared.generate(prompt: prompt)
        
        let json = GeminiClient.cleanJsonString(jsonStr)
        
        struct PromptObj: Decodable {
            let visualPrompt: String
        }
        
        let decoded = try JSONDecoder().decode(PromptObj.self, from: json.data(using: .utf8) ?? Data())
        return decoded.visualPrompt
    }
}
