import Foundation
import SwiftUI
import PhotosUI

/// Drives the capture → OCR → analyze flow and holds the UI state the views
/// observe. The concrete `AnalysisService` is injected, so the mock is used now
/// and a real service can be swapped in later with no view changes.
@MainActor
final class CaptureViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle                 // landing: choosing how to get a photo
        case confirming(UIImage)  // got a photo, awaiting "Use this photo"
        case analyzing            // OCR + analysis in flight
        case result(GuidanceResponse, UIImage)
        case failed(String)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.analyzing, .analyzing): return true
            case let (.failed(a), .failed(b)): return a == b
            case (.confirming, .confirming), (.result, .result): return true
            default: return false
            }
        }
    }

    @Published var phase: Phase = .idle
    @Published var pickerItem: PhotosPickerItem?

    private let analysis: AnalysisService
    private let ocr = OCRService()

    init(analysis: AnalysisService) {
        self.analysis = analysis
    }

    /// Called when a photo is obtained from either the camera or the library.
    func didObtain(image: UIImage) {
        phase = .confirming(image)
    }

    /// Load a UIImage from a PhotosPicker selection.
    func loadPickedImage() async {
        guard let pickerItem else { return }
        do {
            if let data = try await pickerItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                didObtain(image: image)
            } else {
                phase = .failed("That item could not be loaded as an image.")
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
        self.pickerItem = nil
    }

    /// Run OCR on-device, then hand the image + text to the analysis service.
    func analyzeConfirmedImage(_ image: UIImage) async {
        phase = .analyzing
        do {
            // OCR failure should not block analysis — treat text as optional.
            let ocrText = (try? await ocr.recognizeText(in: image)) ?? ""
            let response = try await analysis.analyze(image: image, ocrText: ocrText)
            phase = .result(response, image)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func reset() {
        phase = .idle
        pickerItem = nil
    }
}
