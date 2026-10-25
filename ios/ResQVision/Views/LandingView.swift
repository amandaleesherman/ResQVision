import SwiftUI
import PhotosUI

/// Camera-first landing screen.
///
/// On a real device it shows a live camera preview with a capture button. On
/// the simulator (no camera) or when permission is denied, it gracefully shows
/// a clear message and makes the photo library the primary path — so the full
/// flow is usable during simulator UI development.
struct LandingView: View {
    @StateObject private var model = CaptureViewModel(analysis: MockAnalysisService())
    @StateObject private var camera = CameraController()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("ResQVision")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            captureEntry
        case .confirming(let image):
            PhotoConfirmView(
                image: image,
                onUse: { Task { await model.analyzeConfirmedImage(image) } },
                onRetake: { model.reset() }
            )
        case .analyzing:
            AnalyzingView()
        case .result(let response, let image):
            ResponseView(response: response, image: image, onDone: { model.reset() })
        case .failed(let message):
            ErrorView(message: message, onRetry: { model.reset() })
        }
    }

    // MARK: - Capture entry (camera-first with library fallback)

    private var captureEntry: some View {
        VStack(spacing: 0) {
            ZStack {
                if camera.isAvailable {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea(edges: .horizontal)
                } else {
                    cameraUnavailablePlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls
        }
        .task {
            await camera.configure()
        }
        .onChange(of: model.pickerItem) { _, _ in
            Task { await model.loadPickedImage() }
        }
        .onDisappear { camera.stop() }
    }

    private var controls: some View {
        VStack(spacing: 16) {
            Text("Point the camera at the injury, or choose a photo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                if camera.isAvailable {
                    Button {
                        Task {
                            if let image = try? await camera.capturePhoto() {
                                model.didObtain(image: image)
                            }
                        }
                    } label: {
                        Label("Capture", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    // When the camera is the primary action, the library is
                    // the secondary (bordered) button.
                    PhotosPicker(selection: $model.pickerItem, matching: .images) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    // No camera (e.g. Simulator) → the library is the primary
                    // (prominent) action.
                    PhotosPicker(selection: $model.pickerItem, matching: .images) {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var cameraUnavailablePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(cameraMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var cameraMessage: String {
        switch camera.authorization {
        case .denied, .restricted:
            return "Camera access is off. You can enable it in Settings, or pick a photo from your library below."
        default:
            return "No camera is available here (this is normal on the Simulator). Choose a photo from your library below."
        }
    }
}

// MARK: - Loading state

struct AnalyzingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Analyzing photo…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error state

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LandingView()
}
