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

/// The screens the app moves between.
enum Screen {
    case home
    case camera
    case library
    case preview
    case loading
    case questionnaire
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

    /// The vision analysis awaiting clarifying answers (questionnaire step).
    var pendingAnalysis: WoundAnalysis?

    /// The live engine. AIGuidanceEngine supports the two-phase (vision →
    /// questionnaire → guidance) flow. Swap to StubGuidanceEngine() to demo
    /// the UI offline (it skips the questionnaire).
    @ObservationIgnored var engine: GuidanceEngine = AIGuidanceEngine()

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

    /// Runs analysis and advances the flow. Called by the loading screen's
    /// .task. For the AI engine this runs vision first and, if the model is
    /// uncertain and has clarifying questions, routes to the questionnaire
    /// before producing guidance. Otherwise it goes straight to results.
    func runAnalysis() async {
        guard let image = selectedImage else {
            errorMessage = GuidanceError.noImage.localizedDescription
            result = nil
            screen = .results
            return
        }

        // Two-phase path (vision → optional questionnaire → guidance).
        if let ai = engine as? AIGuidanceEngine {
            let analysis = await ai.analyzeVision(image: image)
            if !analysis.clarifyingQuestions.isEmpty {
                pendingAnalysis = analysis
                screen = .questionnaire
                return
            }
            result = await ai.buildGuidance(analysis: analysis, answers: [:])
            screen = .results
            return
        }

        // One-shot path (e.g. the stub engine).
        do {
            result = try await engine.analyze(image: image)
        } catch {
            result = nil
            errorMessage = error.localizedDescription
        }
        screen = .results
    }

    /// Called by the questionnaire screen once the user answers. Builds the
    /// final guidance using the pending analysis plus the answers.
    func finishWithAnswers(_ answers: [String: String]) async {
        guard let analysis = pendingAnalysis, let ai = engine as? AIGuidanceEngine else {
            screen = .results
            return
        }
        screen = .loading
        result = await ai.buildGuidance(analysis: analysis, answers: answers)
        pendingAnalysis = nil
        screen = .results
    }

    /// Resets everything back to the home screen.
    func reset() {
        selectedImage = nil
        result = nil
        errorMessage = nil
        pendingAnalysis = nil
        screen = .home
    }
}
