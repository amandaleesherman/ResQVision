//
//  AIGuidanceEngine.swift
//  EmergencyFirst
//
//  The real GuidanceEngine. It wires the three components together, each
//  doing one job:
//
//    1. Vision (GeminiVisionAnalyzer): extracts OBSERVABLE features only.
//    2. RAG (FirstAidKnowledgeBase): retrieves first-aid guidance from the
//       three approved sources, matched to the observed features.
//    3. Synthesis (Gemini text): combines the features + retrieved guidance
//       into cautious, grounded steps — WITHOUT diagnosing from the image.
//
//  Flip AppState.engine to this to go live.
//

import UIKit

nonisolated struct AIGuidanceEngine: GuidanceEngine {
    var vision: WoundVisionAnalyzer = GeminiVisionAnalyzer()
    var retriever: GuidanceRetriever = FirstAidKnowledgeBase()

    /// One-shot path (protocol requirement): vision + guidance, no questionnaire.
    func analyze(image: UIImage) async throws -> GuidanceResult {
        let analysis = await analyzeVision(image: image)
        return await buildGuidance(analysis: analysis, answers: [:])
    }

    /// Phase 1: run vision only. Returns an "unclear" fallback analysis if the
    /// Gemini endpoint is unreachable, so the flow never dead-ends.
    func analyzeVision(image: UIImage) async -> WoundAnalysis {
        if let result = try? await vision.analyze(image: image) {
            return result
        }
        return WoundAnalysis(
            visibleRedness: .unsure,
            apparentWoundType: "unclear",
            bleedingVisibility: .unsure,
            imageQuality: .poor,
            uncertainty: 1.0,
            observations: "Automatic photo analysis was unavailable, so this is general first-aid guidance. Assess the injury yourself and seek professional care if unsure."
        )
    }

    /// Phase 2: retrieve + synthesize. `answers` are optional questionnaire
    /// responses (question → selected answer text) that sharpen the result.
    func buildGuidance(analysis: WoundAnalysis, answers: [String: String]) async -> GuidanceResult {
        let visionFailed = analysis.apparentWoundType == "unclear" && analysis.uncertainty >= 1.0

        // RAG: retrieve grounded guidance from approved sources.
        let docs = retriever.retrieve(for: analysis)

        let isSevere = analysis.bleedingVisibility == .heavy
            || docs.contains(where: { $0.topic == "Severe bleeding" })

        let title: String
        let steps: [String]
        var supplies: [Supply] = []
        var longerTermCare: [String] = []
        if !visionFailed, let synthesized = try? await synthesize(analysis: analysis, docs: docs, answers: answers) {
            title = synthesized.title.isEmpty
                ? "First-aid guidance for an apparent \(analysis.apparentWoundType)"
                : synthesized.title
            steps = synthesized.steps
            supplies = synthesized.supplies
            longerTermCare = synthesized.longerTermCare
        } else if visionFailed {
            title = "General first-aid guidance (photo analysis unavailable)"
            steps = docs.map { "\($0.topic): \($0.content)" }
        } else {
            title = "First-aid guidance for an apparent \(analysis.apparentWoundType)"
            steps = docs.map { "\($0.topic): \($0.content)" }
        }

        return GuidanceResult(
            title: title,
            steps: steps,
            isSevere: isSevere,
            analysis: analysis,
            sources: docs,
            supplies: supplies,
            longerTermCare: longerTermCare
        )
    }

    // MARK: - Synthesis

    private struct Synthesized {
        let title: String
        let steps: [String]
        let supplies: [Supply]
        let longerTermCare: [String]
    }

    private func synthesize(analysis: WoundAnalysis, docs: [GuidanceDocument], answers: [String: String]) async throws -> Synthesized {
        let apiKey = Secrets.geminiAPIKey
        guard !apiKey.isEmpty, apiKey != "PASTE_YOUR_GEMINI_API_KEY_HERE" else {
            throw GuidanceError.analysisFailed
        }

        let sourcesText = docs.enumerated().map { i, doc in
            "[\(i + 1)] \(doc.source.rawValue) — \(doc.topic): \(doc.content)"
        }.joined(separator: "\n")

        let answersText = answers.isEmpty
            ? "none provided"
            : answers.map { "\($0.key): \($0.value)" }.joined(separator: "; ")

        let prompt = """
        You are a careful first-aid assistant. You are given (a) OBSERVABLE \
        features extracted from a photo and (b) first-aid guidance retrieved \
        from trusted sources. Produce cautious, general first-aid steps.

        Hard rules:
        - Do NOT diagnose a medical condition from the image. Frame everything as \
        general first-aid guidance based on what is visible.
        - Ground your steps ONLY in the retrieved guidance below. Do not invent \
        medical claims.
        - If uncertainty is high or image quality is poor, say the photo may be \
        unclear and recommend caution.
        - Always remind the user to seek professional care / call emergency \
        services for anything serious.

        Observable features (JSON): \
        redness=\(analysis.visibleRedness.rawValue), \
        apparentType=\(analysis.apparentWoundType), \
        bleeding=\(analysis.bleedingVisibility.rawValue), \
        imageQuality=\(analysis.imageQuality.rawValue), \
        uncertainty=\(analysis.uncertainty), \
        notes=\(analysis.observations)

        User's answers to clarifying questions (use these to be more specific): \
        \(answersText)

        Retrieved guidance:
        \(sourcesText)

        Return a JSON object with:
        - title: a short, cautious headline (no diagnosis)
        - steps: an array of 3–6 short IMMEDIATE first-aid step strings
        - supplies: an array of 2–4 objects {name, reason, symbol} for tools/
          supplies or OTC medication CATEGORIES that could help. `symbol` must be
          a valid SF Symbol name chosen from: "bandage.fill", "cross.case.fill",
          "drop.fill", "pills.fill", "hand.raised.fill", "scissors",
          "waterbottle.fill", "thermometer.medium", "snowflake". Do not name
          specific brands or dosages.
        - longerTermCare: an array of 2–4 short strings on longer-term care
          (keeping clean, watching for infection, when to see a clinician)
        """

        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 8 // short per-attempt; GeminiHTTP retries
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json", "temperature": 0.3]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await GeminiHTTP.send(request, attempts: 3)
        return try decodeSynthesis(from: data)
    }

    private func decodeSynthesis(from data: Data) throws -> Synthesized {
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
        struct Payload: Decodable {
            let title: String?
            let steps: [String]?
            let supplies: [Supply]?
            let longerTermCare: [String]?
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates.first?.content.parts.first?.text,
              let payloadData = text.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: payloadData) else {
            throw GuidanceError.analysisFailed
        }

        return Synthesized(
            title: payload.title ?? "",
            steps: payload.steps ?? ["Follow the retrieved first-aid guidance and seek professional care if unsure."],
            supplies: sanitize(payload.supplies ?? []),
            longerTermCare: payload.longerTermCare ?? []
        )
    }

    /// Guards against bad SF Symbol names the model might invent, falling back
    /// to a safe default icon so the UI never shows a blank image.
    private func sanitize(_ supplies: [Supply]) -> [Supply] {
        let allowed: Set<String> = [
            "bandage.fill", "cross.case.fill", "drop.fill", "pills.fill",
            "hand.raised.fill", "scissors", "waterbottle.fill",
            "thermometer.medium", "snowflake"
        ]
        return supplies.map { s in
            allowed.contains(s.symbol) ? s
                : Supply(name: s.name, reason: s.reason, symbol: "cross.case.fill")
        }
    }
}
