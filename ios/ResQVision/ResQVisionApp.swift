import SwiftUI

/// App entry point. ResQVision opens camera-first (see `LandingView`).
///
/// Architecture (Workstream A):
///   LandingView → capture/pick a photo → OCRService (on-device) →
///   build an `Observation` → AnalysisService (mock for now, real AI later) →
///   ResponseView (emergency-first guidance with cited sources).
///
/// The AI integration is deliberately behind the `AnalysisService` protocol so
/// the whole UI flow works today against `MockAnalysisService`, with no
/// dependency on a confirmed vision endpoint or API key.
@main
struct ResQVisionApp: App {
    var body: some Scene {
        WindowGroup {
            LandingView()
        }
    }
}
