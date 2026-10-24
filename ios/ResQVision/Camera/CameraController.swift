import AVFoundation
import UIKit

/// Thin wrapper around an `AVCaptureSession` for still-photo capture.
///
/// Simulator-friendly: the iOS Simulator has no camera, so `configure()`
/// detects the absence of a capture device and reports `isAvailable == false`
/// instead of crashing. The UI uses that to fall back to the photo library.
@MainActor
final class CameraController: NSObject, ObservableObject {

    /// Whether a usable camera exists and is authorized. False on the simulator.
    @Published private(set) var isAvailable = false
    /// Authorization state for the camera, surfaced to the UI.
    @Published private(set) var authorization: AVAuthorizationStatus = .notDetermined

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "resqvision.camera.session")

    /// Continuation used to deliver a captured photo back to the async caller.
    private var captureContinuation: CheckedContinuation<UIImage, Error>?

    /// Request authorization and configure the session. Safe to call repeatedly.
    func configure() async {
        authorization = AVCaptureDevice.authorizationStatus(for: .video)

        if authorization == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            authorization = granted ? .authorized : .denied
        }

        guard authorization == .authorized else {
            isAvailable = false
            return
        }

        // No back camera (e.g. the Simulator) → mark unavailable and bail.
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            isAvailable = false
            return
        }

        await configureSession(with: device)
    }

    private func configureSession(with device: AVCaptureDevice) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                guard let self else { continuation.resume(); return }
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if self.session.canAddInput(input) { self.session.addInput(input) }
                    if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
                    self.session.commitConfiguration()
                    self.session.startRunning()
                    Task { @MainActor in self.isAvailable = true }
                } catch {
                    self.session.commitConfiguration()
                    Task { @MainActor in self.isAvailable = false }
                }
                continuation.resume()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    /// Capture a single still photo.
    func capturePhoto() async throws -> UIImage {
        guard isAvailable else { throw CameraError.unavailable }
        return try await withCheckedThrowingContinuation { continuation in
            self.captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            sessionQueue.async { [weak self] in
                self?.photoOutput.capturePhoto(with: settings, delegate: self!)
            }
        }
    }

    enum CameraError: LocalizedError {
        case unavailable
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "The camera is not available on this device."
            case .captureFailed:
                return "Could not capture a photo. Please try again."
            }
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.captureContinuation?.resume(throwing: error)
            } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
                self.captureContinuation?.resume(returning: image)
            } else {
                self.captureContinuation?.resume(throwing: CameraError.captureFailed)
            }
            self.captureContinuation = nil
        }
    }
}
