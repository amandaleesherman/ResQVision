import Foundation
import UIKit

/// A stand-in `AnalysisService` used while the real AI vision endpoint is being
/// confirmed. It lets the entire capture → analyze → response UI flow work end
/// to end today, with zero network dependency or API key.
///
/// IMPORTANT: every result it returns is flagged `isSample = true` and carries
/// the "SAMPLE DATA" provenance label, so mock output can never be mistaken for
/// a real medical analysis. The mock contains NO invented medical instructions
/// — step text is placeholder copy, matching the guidance engine's policy that
/// real first-aid content is human-curated.
struct MockAnalysisService: AnalysisService {
    /// Optional artificial delay to make the loading state visible in the UI.
    var simulatedDelay: Duration = .milliseconds(600)

    func analyze(image: UIImage, ocrText: String) async throws -> GuidanceResponse {
        if simulatedDelay > .zero {
            try? await Task.sleep(for: simulatedDelay)
        }
        // Pick a canned scenario. If OCR found text we nudge toward a
        // "label" style scenario; otherwise default to a wound scenario.
        let scenario: MockScenario = ocrText.isEmpty ? .severeBleeding : .minorCutWithLabel
        return scenario.response(ocrText: ocrText)
    }
}

/// Canned demo scenarios. These exist only to exercise the UI. The step text is
/// deliberately placeholder ("Sample step …") — NOT real medical advice.
enum MockScenario {
    case severeBleeding
    case minorCutWithLabel

    func response(ocrText: String) -> GuidanceResponse {
        switch self {
        case .severeBleeding:
            return GuidanceResponse(
                emergency: .init(
                    callNineOneOne: true,
                    reason: "Severe bleeding (sample scenario)",
                    message: "Call 911 now. Start these steps while you wait or have someone else call."
                ),
                category: "severe_bleeding",
                matchConfidence: .high,
                title: "Control severe bleeding (SAMPLE)",
                steps: [
                    .init(order: 1, text: "Sample step 1 — real guidance comes from the curated knowledge base.", sourceId: "src_sample_1"),
                    .init(order: 2, text: "Sample step 2 — placeholder shown by the mock service.", sourceId: "src_sample_1")
                ],
                warnings: ["This is SAMPLE data from the mock service, not real medical guidance."],
                sources: [
                    .init(
                        id: "src_sample_1",
                        publisher: "SAMPLE — American Red Cross (placeholder)",
                        title: "Placeholder source",
                        url: "https://www.redcross.org/",
                        excerpt: "Placeholder excerpt (mock).",
                        retrievedDate: "2026-10-24"
                    )
                ],
                observationProvenance: .init(
                    source: .sample,
                    isSample: true,
                    label: "SAMPLE DATA — not a real camera analysis."
                ),
                cannotDetermine: ["Depth of wound cannot be determined (sample)."],
                followUpQuestions: ["Is the bleeding slowing after 10 minutes of pressure? (sample)"],
                disclaimer: "This is first-aid guidance, not a medical diagnosis. When in doubt, call 911.",
                isFallback: false,
                engineVersion: "mock-0.1.0"
            )

        case .minorCutWithLabel:
            let ocrNote = ocrText.isEmpty ? "" : " (OCR text captured: \"\(ocrText.prefix(60))\")"
            return GuidanceResponse(
                emergency: .init(
                    callNineOneOne: false,
                    reason: nil,
                    message: "If the situation gets worse or you are unsure, call 911."
                ),
                category: "minor_cut_scrape",
                matchConfidence: .medium,
                title: "Care for a minor cut or scrape (SAMPLE)",
                steps: [
                    .init(order: 1, text: "Sample step 1 — placeholder from the mock service.\(ocrNote)", sourceId: "src_sample_2")
                ],
                warnings: ["This is SAMPLE data from the mock service, not real medical guidance."],
                sources: [
                    .init(
                        id: "src_sample_2",
                        publisher: "SAMPLE — Mayo Clinic (placeholder)",
                        title: "Placeholder source",
                        url: "https://www.mayoclinic.org/",
                        excerpt: "Placeholder excerpt (mock).",
                        retrievedDate: "2026-10-24"
                    )
                ],
                observationProvenance: .init(
                    source: .sample,
                    isSample: true,
                    label: "SAMPLE DATA — not a real camera analysis."
                ),
                cannotDetermine: [],
                followUpQuestions: ["Is the cut deep or still bleeding after pressure? (sample)"],
                disclaimer: "This is first-aid guidance, not a medical diagnosis. When in doubt, call 911.",
                isFallback: false,
                engineVersion: "mock-0.1.0"
            )
        }
    }
}
