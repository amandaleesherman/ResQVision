//
//  CameraFlowView.swift
//  EmergencyFirst
//
//  Wraps the camera with permission handling. Before showing the live camera
//  it checks the camera authorization status:
//
//   • authorized      → show CameraPicker (live camera)
//   • notDetermined   → ask iOS for permission, then react to the answer
//   • denied/restricted → show a friendly "enable camera in Settings" screen
//     with a button that deep-links to the app's Settings page, instead of a
//     confusing black camera screen.
//
//  On the simulator (no camera hardware) it falls back to the photo library
//  so the flow stays testable.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraFlowView: View {
    let appState: AppState

    /// Mirrors AVCaptureDevice camera authorization, tracked in @State so the
    /// view updates when the user answers the permission prompt.
    @State private var status = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        Group {
            // No camera hardware (e.g. simulator): use the library instead.
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                PhotoLibraryPicker(
                    onImage: { appState.didSelect(image: $0) },
                    onCancel: { appState.reset() }
                )
            } else {
                switch status {
                case .authorized:
                    CameraPicker(
                        onImage: { appState.didSelect(image: $0) },
                        onCancel: { appState.reset() }
                    )
                    .ignoresSafeArea()

                case .notDetermined:
                    // Ask once. The prompt shows NSCameraUsageDescription.
                    ProgressView("Requesting camera access…")
                        .task { await requestAccess() }

                default:
                    // .denied or .restricted
                    CameraDeniedView(
                        onOpenSettings: openSettings,
                        onUseLibrary: {
                            // Let the user continue via the library instead.
                            appState.startLibrary()
                        },
                        onCancel: { appState.reset() }
                    )
                }
            }
        }
    }

    /// Requests camera permission and updates `status` with the result.
    private func requestAccess() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        status = granted ? .authorized : .denied
    }

    /// Opens this app's page in the Settings app so the user can flip the
    /// camera toggle back on.
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Shown when camera access is denied or restricted.
private struct CameraDeniedView: View {
    let onOpenSettings: () -> Void
    let onUseLibrary: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Camera Access Needed")
                .font(.title2)
                .fontWeight(.semibold)

            Text("EmergencyFirst can't use the camera because access is turned off. You can turn it on in Settings, or choose a photo from your library instead.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: onOpenSettings) {
                    Label("Open Settings", systemImage: "gear")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button(action: onUseLibrary) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                Button("Cancel", action: onCancel)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
        }
        .padding()
    }
}

#Preview {
    CameraFlowView(appState: AppState())
}
