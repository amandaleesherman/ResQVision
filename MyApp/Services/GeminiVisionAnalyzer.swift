//
//  GeminiVisionAnalyzer.swift
//  EmergencyFirst
//
//  Sends a wound photo to Google's Gemini vision model (gemini-3.8-flash) and
//  asks it to return ONLY observable features as structured JSON, decoded into
//  WoundAnalysis. It does not ask for, and must not produce, a diagnosis.
//
//  The API key is read from Secrets.geminiAPIKey (gitignored). For a public
//  demo this should move behind a server proxy — only `baseURL` changes.
//

import UIKit

protocol WoundVisionAnalyzer: Sendable {
    func analyze(image: UIImage) async throws -> WoundAnalysis
}

nonisolated struct GeminiVisionAnalyzer: WoundVisionAnalyzer {
    /// Fast, non-thinking multimodal model. gemini-3.8-flash was ~10–13s per
    /// call (heavy reasoning, can't disable) — far too slow for an emergency
    /// app. gemini-3.5-flash-lite returns images in ~1s. Swap baseURL for a
    /// proxy before a public demo.
    var baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")!
    var apiKey: String = Secrets.geminiAPIKey

    func analyze(image: UIImage) async throws -> WoundAnalysis {
        guard !apiKey.isEmpty, apiKey != "PASTE_YOUR_GEMINI_API_KEY_HERE" else {
            throw GuidanceError.analysisFailed
        }
        // Downscale before upload: fewer image tokens = faster, and the model
        // doesn't need full resolution to read observable features.
        let scaled = image.downscaled(maxDimension: 768)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.6) else {
            throw GuidanceError.noImage
        }

        let request = try makeRequest(imageBase64: jpeg.base64EncodedString())
        // The Gemini endpoint intermittently stalls (0 bytes, never responds).
        // Retry with a short per-attempt timeout so a single hang doesn't block
        // a time-critical result.
        let data = try await GeminiHTTP.send(request, attempts: 3)
        return try decodeAnalysis(from: data)
    }

    // MARK: - Request

    private func makeRequest(imageBase64: String) throws -> URLRequest {
        let prompt = """
        You are assisting a first-aid app. Look at the photo and describe ONLY \
        what is visually observable about a possible wound. Do NOT diagnose, name \
        a medical condition, or infer anything not visible. If the image is \
        unclear, say so and raise uncertainty.

        Return a JSON object with exactly these fields:
        - visibleRedness: one of "none","mild","moderate","significant","unsure"
        - apparentWoundType: short lowercase phrase of how it LOOKS (e.g. "scrape", \
        "cut/laceration","burn","bruise","puncture","unclear")
        - bleedingVisibility: one of "none","minor","moderate","heavy","unsure"
        - imageQuality: one of "good","fair","poor"
        - uncertainty: a number 0.0–1.0 (higher = less confident)
        - observations: one or two plain observational sentences
        - clarifyingQuestions: an array. ONLY include questions if you are \
        uncertain (uncertainty >= 0.4) and answers would meaningfully improve \
        classification. If you are confident, return an EMPTY array. Max 3 \
        questions. Each item is {question, options, allowsMultiple}. Use short, \
        plain options. Examples: {"question":"How did you get this?","options":\
        ["falling","cutting","hitting a surface","burn","not sure"],\
        "allowsMultiple":false}; {"question":"How long have you had it?",\
        "options":["hours","days","weeks","months"],"allowsMultiple":false}; \
        {"question":"Any of these symptoms?","options":["bleeding","swelling",\
        "itching","spreading/growing","warmth"],"allowsMultiple":true}
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": imageBase64]]
                ]
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.2
            ]
        ]

        // API key via header (x-goog-api-key) rather than the URL query string.
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 8 // short per-attempt; GeminiHTTP retries
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Response

    /// Gemini wraps the model's text (our JSON) in candidates/content/parts.
    /// We pull out the text part and decode it into WoundAnalysis.
    private func decodeAnalysis(from data: Data) throws -> WoundAnalysis {
        struct GeminiResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let json = decoded.candidates.first?.content.parts.first?.text,
              let jsonData = json.data(using: .utf8) else {
            throw GuidanceError.analysisFailed
        }

        return try JSONDecoder().decode(WoundAnalysis.self, from: jsonData)
    }
}

// MARK: - Image helper

nonisolated extension UIImage {
    /// Returns a copy scaled so its largest side is at most `maxDimension`,
    /// preserving aspect ratio. Smaller images upload and process faster.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
