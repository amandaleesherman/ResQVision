//
//  LoadingView.swift
//  EmergencyFirst
//
//  Shown while the guidance engine analyzes the photo. It kicks off the
//  analysis in a .task and, when the result returns, asks AppState to move
//  on to the results screen.
//
//  The analysis itself lives in AppState.runAnalysis(), which calls the
//  GuidanceEngine. The teammate's real engine plugs in there with no change
//  to this view.
//

import SwiftUI

struct LoadingView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)

            Text("Analyzing the situation…")
                .font(.headline)

            Text("Hang tight — getting first-aid guidance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            await appState.runAnalysis()
        }
    }
}

#Preview {
    LoadingView(appState: AppState())
}
