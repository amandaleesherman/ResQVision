//
//  GuidanceEngine.swift
//  EmergencyFirst
//
//  The contract between the UI (Person 1) and the guidance engine teammate.
//  Any type that can turn a photo into first-aid guidance conforms to this.
//
//  The UI only ever talks to this protocol, so the real engine can be
//  dropped in later by assigning a different implementation to
//  AppState.engine — no view code changes.
//

import UIKit

protocol GuidanceEngine: Sendable {
    /// Analyzes the photo and returns structured first-aid guidance.
    /// Throws if analysis fails (no network, bad image, etc.).
    func analyze(image: UIImage) async throws -> GuidanceResult
}

/// Errors the UI knows how to show.
enum GuidanceError: LocalizedError {
    case noImage
    case analysisFailed

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "No photo was provided to analyze."
        case .analysisFailed:
            return "Couldn't analyze the photo. Please try again."
        }
    }
}
