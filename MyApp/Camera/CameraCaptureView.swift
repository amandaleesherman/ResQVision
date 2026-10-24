//
//  CameraCaptureView.swift
//  EmergencyFirst
//
//  A live camera built on AVCaptureSession, replacing UIImagePickerController
//  (which can show a black preview on newer iOS).
//
//  It owns an AVCaptureSession, shows its live feed via an
//  AVCaptureVideoPreviewLayer, and captures a still photo with
//  AVCapturePhotoOutput when the shutter is tapped.
//
//  Design notes that matter for getting a *non-black* preview:
//   • The session is configured and start/stop'd on a background queue, never
//     the main thread (main-thread startRunning() can freeze the preview).
//   • Session setup surfaces any failure into `setupError` instead of silently
//     skipping the camera input, so a misconfigured session shows a readable
//     message rather than a black rectangle.
//   • The preview layer is attached to the session before the session starts.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraCaptureView: View {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var camera: CameraController?
    @State private var setupError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Live preview (once the controller exists).
            if let camera {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            }

            // If setup failed, show why instead of a silent black screen.
            if let error = setupError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.yellow)
                    Text("Camera couldn't start")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            // Controls overlay.
            VStack {
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.4), in: Circle())
                    }

                    Spacer()

                    // Flip between back and front cameras.
                    if setupError == nil, let camera {
                        Button {
                            camera.switchCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.black.opacity(0.4), in: Circle())
                        }
                    }
                }
                .padding()

                Spacer()

                // Shutter button (hidden if setup failed).
                if setupError == nil, let camera {
                    Button {
                        camera.capturePhoto { image in
                            if let image { onImage(image) }
                        }
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle().stroke(.white.opacity(0.6), lineWidth: 4)
                                    .frame(width: 84, height: 84)
                            )
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            let controller = CameraController(onSetupError: { message in
                setupError = message
            })
            camera = controller
            await controller.start()
        }
        .onDisappear {
            camera?.stop()
        }
    }
}

// MARK: - Preview layer bridge

/// Hosts an AVCaptureVideoPreviewLayer inside SwiftUI via a UIView subclass
/// whose backing layer IS the preview layer.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Capture session controller

/// Owns the capture session and still-photo output. Runs session setup and
/// start/stop on a dedicated serial queue.
///
/// Marked `nonisolated` so it genuinely runs OFF the main actor. The project
/// defaults new types to @MainActor isolation, but AVFoundation's capture
/// session and photo-capture delegate must run off the main actor — pinning
/// this to the main actor stalls the capture pipeline and yields a black
/// preview.
nonisolated final class CameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    /// Called on the main actor if session setup fails; wired by the view.
    private let onSetupError: @MainActor (String) -> Void

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var captureCompletion: ((UIImage?) -> Void)?

    /// The camera currently in use. Starts on the back camera.
    private var position: AVCaptureDevice.Position = .back
    /// The active camera input, kept so we can remove it when switching.
    private var currentInput: AVCaptureDeviceInput?

    init(onSetupError: @escaping @MainActor (String) -> Void) {
        self.onSetupError = onSetupError
        super.init()
    }

    /// Configures (once) and starts the session.
    func start() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !self.isConfigured {
                    self.configure()
                }
                if self.isConfigured, !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// Builds the session: camera input for `position` + photo output.
    /// Records a readable reason via `setupError` if any required step fails.
    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Add the camera input for the current position.
        guard addInput(for: position) else {
            session.commitConfiguration()
            return // addInput already reported the specific failure.
        }

        // Add the photo output.
        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            setFailure("The photo output couldn't be added to the session.")
            return
        }
        session.addOutput(photoOutput)

        session.commitConfiguration()
        isConfigured = true
    }

    /// Finds the camera for `position`, creates an input, and adds it to the
    /// session. Returns false (and reports a reason) if it couldn't.
    /// Must be called inside a beginConfiguration/commitConfiguration block.
    private func addInput(for position: AVCaptureDevice.Position) -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
            ?? AVCaptureDevice.default(for: .video) else {
            setFailure(position == .front
                ? "No front camera was found on this device."
                : "No camera device was found on this device.")
            return false
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            setFailure("Couldn't open the camera: \(error.localizedDescription)")
            return false
        }

        guard session.canAddInput(input) else {
            setFailure("The camera input couldn't be added to the session.")
            return false
        }
        session.addInput(input)
        currentInput = input
        return true
    }

    /// Flips between the back and front cameras by swapping the session input.
    func switchCamera() {
        sessionQueue.async {
            guard self.isConfigured else { return }

            let newPosition: AVCaptureDevice.Position = (self.position == .back) ? .front : .back

            self.session.beginConfiguration()

            // Remove the old input.
            if let existing = self.currentInput {
                self.session.removeInput(existing)
                self.currentInput = nil
            }

            // Try to add the new one; if it fails, fall back to the old camera.
            if self.addInput(for: newPosition) {
                self.position = newPosition
            } else {
                _ = self.addInput(for: self.position)
            }

            self.session.commitConfiguration()
        }
    }

    private func setFailure(_ message: String) {
        let callback = onSetupError
        Task { @MainActor in callback(message) }
    }

    /// Captures a single still photo; the completion runs on the main actor.
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async {
            guard self.session.isRunning else {
                Task { @MainActor in completion(nil) }
                return
            }
            self.captureCompletion = completion
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let image: UIImage? = {
            guard error == nil, let data = photo.fileDataRepresentation() else { return nil }
            return UIImage(data: data)
        }()

        let completion = captureCompletion
        captureCompletion = nil
        Task { @MainActor in
            completion?(image)
        }
    }
}
