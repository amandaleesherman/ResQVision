//
//  GuidanceResult.swift
//  EmergencyFirst
//
//  The structured result returned by the guidance engine. Using a model
//  (instead of a plain String) gives the UI something richer to show and
//  gives the engine teammate a clear contract to fill in.
//

import Foundation

struct GuidanceResult: Identifiable, Equatable {
    let id = UUID()

    /// A short headline, e.g. "Possible minor burn".
    let title: String

    /// Ordered first-aid steps the user should follow.
    let steps: [String]

    /// Whether the situation looks serious enough to call emergency services.
    /// The UI uses this to emphasize the warning.
    let isSevere: Bool

    static func == (lhs: GuidanceResult, rhs: GuidanceResult) -> Bool {
        lhs.id == rhs.id
    }
}
