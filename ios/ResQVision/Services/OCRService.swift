import Foundation
import UIKit
import Vision

/// On-device optical character recognition using Apple's Vision framework
/// (`VNRecognizeTextRequest`). Runs offline, keeps images private, and works on
/// both the simulator and a device.
///
/// Used to extract any printed text in a photo (e.g. a medication label or a
/// first-aid leaflet). It does NOT interpret wounds — that is the vision
/// model's job, handled later by the `AnalysisService`.
struct OCRService {

    /// Recognize text in an image. Returns an empty string if no text is found
    /// (this is a normal result, not an error).
    func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            // Accurate mode + language correction suits short, printed labels.
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation, options: [:])
            // Vision work is synchronous and can be heavy; run off the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                }
            }
        }
    }

    enum OCRError: LocalizedError {
        case invalidImage
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "The image could not be read for text recognition."
            case .recognitionFailed(let msg):
                return "Text recognition failed: \(msg)"
            }
        }
    }
}

extension UIImage {
    /// Map UIImage orientation to the CGImagePropertyOrientation Vision expects,
    /// so text is recognized regardless of how the photo was taken.
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
