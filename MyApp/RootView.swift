//
//  RootView.swift
//  EmergencyFirst
//
//  The top-level view. It owns the single AppState instance and shows the
//  correct screen based on appState.screen, driving the flow:
//  home → (camera OR library) → preview → loading → results → home.
//

import SwiftUI

struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        switch appState.screen {
        case .home:
            HomeView(appState: appState)
        case .camera:
            // CameraFlowView handles permission checks (and the simulator
            // fallback) before showing the live camera.
            CameraFlowView(appState: appState)
        case .library:
            PhotoLibraryPicker(
                onImage: { appState.didSelect(image: $0) },
                onCancel: { appState.reset() }
            )
        case .preview:
            PhotoPreviewView(appState: appState)
        case .loading:
            LoadingView(appState: appState)
        case .questionnaire:
            QuestionnaireView(appState: appState)
        case .results:
            ResultsView(appState: appState)
        }
    }
}

#Preview {
    RootView()
}
