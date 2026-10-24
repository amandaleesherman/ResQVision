//
//  WoundAnalysis.swift
//  EmergencyFirst
//
//  The structured, OBSERVABLE features the vision model extracts from a photo.
//  This is deliberately NOT a diagnosis — it only describes what is visible,
//  plus the model's own uncertainty and an assessment of image quality.
//
//  The vision model is asked to return exactly this shape as JSON, so it
//  decodes directly from the API response.
//

import Foundation

nonisolated struct WoundAnalysis: Codable, Equatable {
    /// Visible redness around the area: none / mild / moderate / significant / unsure.
    let visibleRedness: Level

    /// Apparent wound type as it LOOKS (not a diagnosis), e.g. "scrape",
    /// "cut/laceration", "burn", "bruise", "puncture", "unclear".
    let apparentWoundType: String

    /// How visible any bleeding is: none / minor / moderate / heavy / unsure.
    let bleedingVisibility: Level

    /// Whether the photo is clear enough to assess: good / fair / poor.
    let imageQuality: ImageQuality

    /// The model's confidence that its observations are reliable, 0.0–1.0.
    let uncertainty: Double

    /// Short notes on what is visible. Plain, observational language only.
    let observations: String

    nonisolated enum Level: String, Codable {
        case none, mild, minor, moderate, significant, heavy, unsure
    }

    nonisolated enum ImageQuality: String, Codable {
        case good, fair, poor
    }
}
