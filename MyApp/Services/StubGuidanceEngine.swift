//
//  StubGuidanceEngine.swift
//  EmergencyFirst
//
//  A stub implementation of GuidanceEngine so the UI flow works end to end
//  before the real engine is ready. The teammate's engine will provide its
//  own GuidanceEngine conformance; swapping it in is a one-line change in
//  AppState (see AppState.engine) with no view changes.
//

import UIKit

struct StubGuidanceEngine: GuidanceEngine {
    func analyze(image: UIImage) async throws -> GuidanceResult {
        // Simulate work so the loading screen is visible.
        try? await Task.sleep(for: .seconds(1.5))

        return GuidanceResult(
            title: "Placeholder guidance (engine not connected yet)",
            steps: [
                "Make sure the scene is safe before helping.",
                "Check whether the person is responsive and breathing.",
                "Call your local emergency number if the situation is serious."
            ],
            isSevere: false
        )
    }
}
