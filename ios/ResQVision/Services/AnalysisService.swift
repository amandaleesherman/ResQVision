import Foundation
import UIKit

/// The seam between the app and the AI/guidance backend.
///
/// Everything the UI needs is expressed here. The app does NOT know or care
/// whether analysis is mocked, runs on-device, or calls a remote vision model.
/// Swap the concrete type in one place (`LandingView`) when the real endpoint
/// is confirmed — no UI changes required.
protocol AnalysisService {
    /// Analyze a captured/selected image plus any on-device OCR text, and
    /// return structured first-aid guidance.
    ///
    /// - Parameters:
    ///   - image: The wound/scene photo the user captured or picked.
    ///   - ocrText: Text extracted on-device (e.g. from a medication label).
    ///              May be empty.
    /// - Returns: A `GuidanceResponse` (emergency-first, source-cited).
    func analyze(image: UIImage, ocrText: String) async throws -> GuidanceResponse
}

/// Errors surfaced to the UI. Kept small and user-presentable.
enum AnalysisError: LocalizedError {
    case notConfigured
    case network(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Analysis service is not configured yet."
        case .network(let msg):
            return "Could not reach the analysis service: \(msg)"
        case .decoding(let msg):
            return "Could not read the analysis response: \(msg)"
        }
    }
}
