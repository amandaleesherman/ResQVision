//
//  PhotoPreviewView.swift
//  EmergencyFirst
//
//  Shows the photo the user captured or picked and lets them confirm it
//  ("Analyze") or go back and pick again ("Retake"). The image comes from
//  AppState.selectedImage.
//

import SwiftUI

struct PhotoPreviewView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            Text("Confirm Photo")
                .font(.title2)
                .fontWeight(.semibold)

            // Show the selected image, or a fallback if somehow missing.
            if let image = appState.selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.secondary.opacity(0.15))
                    .frame(maxWidth: .infinity, maxHeight: 420)
                    .overlay {
                        Label("No photo", systemImage: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            Text("Make sure the situation is clearly visible.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    appState.beginAnalysis()
                } label: {
                    Label("Analyze", systemImage: "waveform.badge.magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    appState.reset()
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#Preview {
    let state = AppState()
    state.selectedImage = UIImage(systemName: "photo")
    return PhotoPreviewView(appState: state)
}
