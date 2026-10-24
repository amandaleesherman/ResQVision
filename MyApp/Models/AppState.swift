//
//  AppState.swift
//  EmergencyFirst
//
//  Holds the app's current screen and the data shared between screens.
//  RootView watches this object and shows the right screen for `screen`.
//
//  The flow is:
//    home → (camera OR library) → preview → loading → results → home
//

import SwiftUI

/// The five screens the app moves between.
enum Screen {
    case home
    case camera
    case library
    case preview
    case loading
    case results
}

/// A single source of truth for the whole app.
///
/// Marked @Observable so SwiftUI views automatically update when any of
/// these properties change. One instance is created in RootView and passed
/// down to the child screens.
@Observable
final class AppState {
    /// Which screen is currently shown.
    var screen: Screen = .home

    /// The photo the user captured or picked. Set during preview, read by loading.
    var selectedImage: UIImage?

    /// The structured guidance produced by the engine. Read by the results screen.
    var result: GuidanceResult?

    /// A human-readable error message if analysis failed.
    var errorMessage: String?

    /// The engine that turns a photo into guidance. Defaults to the stub;
    /// swap in the teammate's real engine here with no view changes.
    @ObservationIgnored var engine: GuidanceEngine = StubGuidanceEngine()

    // MARK: - Flow helpers
    // These small methods keep screen transitions in one place so the
    // individual views stay simple and consistent.

    func startCamera() {
        screen = .camera
    }

    func startLibrary() {
        screen = .library
    }

    /// Called once an image has been obtained from the camera or library.
    func didSelect(image: UIImage) {
        selectedImage = image
        screen = .preview
    }

    /// Called from the preview screen when the user confirms the photo.
    /// Moves to the loading screen and runs the engine.
    func beginAnalysis() {
        errorMessage = nil
        screen = .loading
    }

    /// Runs the guidance engine on the selected image and advances the flow.
    /// Called by the loading screen's .task.
    func runAnalysis() async {
        guard let image = selectedImage else {
            errorMessage = GuidanceError.noImage.localizedDescription
            result = nil
            screen = .results
            return
        }

        do {
            result = try await engine.analyze(image: image)
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
        screen = .results
    }

    /// Resets everything back to the home screen.
    func reset() {
        selectedImage = nil
        result = nil
        errorMessage = nil
        screen = .home
    }
}
