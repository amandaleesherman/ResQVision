//
//  HomeView.swift
//  EmergencyFirst
//
//  The first screen the user sees. It explains what the app does and offers
//  two ways to provide a photo of the situation: take a new photo with the
//  camera, or choose an existing one from the photo library. Both buttons
//  ask AppState to move to the matching screen.
//

import SwiftUI

struct HomeView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App identity
            VStack(spacing: 12) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red)

                Text("EmergencyFirst")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Snap a photo of the situation and get first-aid guidance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            // Entry points
            VStack(spacing: 16) {
                Button {
                    appState.startCamera()
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    appState.startLibrary()
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .padding()
    }
}

#Preview {
    HomeView(appState: AppState())
}
