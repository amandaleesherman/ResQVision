import AVFoundation
import UIKit

/// Thin wrapper around an `AVCaptureSession` for still-photo capture.
///
/// Concurrency model: the published UI state (`isAvailable`, `authorization`)
/// lives on the main actor so SwiftUI can observe it. The AVFoundation objects
/// (`session`, `photoOutput`) are driven exclusively on a private serial queue
/// and are marked `nonisolated(unsafe)` — the correct annotation for objects
/// that are internally thread-safe and intentionally used off the main actor.
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

    /// Driven on `sessionQueue`; safe to read for the preview layer on main.
    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated private let sessionQueue = DispatchQueue(label: "resqvision.camera.session")

    /// Delivers a captured photo back to the async caller. Only touched on the
    /// main actor (set in `capturePhoto`, consumed in the delegate callback).
    private var captureContinuation: CheckedContinuation<UIImage, Error>?

    /// Request authorization and configure the session. Safe to call repeatedly.
    func configure() async {
        var status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            status = granted ? .authorized : .denied
        }
        authorization = status

        guard status == .authorized else {
            isAvailable = false
            return
        }

        // No back camera (e.g. the Simulator) → mark unavailable and bail.
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            || AVCaptureDevice.default(for: .video) != nil else {
            isAvailable = false
            return
        }

        let configured = await configureSession()
        isAvailable = configured
    }

    /// All session mutation happens here, on the private serial queue. Returns
    /// whether the session was configured and started successfully.
    private func configureSession() async -> Bool {
        let session = self.session
        let photoOutput = self.photoOutput
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            sessionQueue.async {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    ?? AVCaptureDevice.default(for: .video) else {
                    continuation.resume(returning: false)
                    return
                }
                session.beginConfiguration()
                session.sessionPreset = .photo
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if session.canAddInput(input) { session.addInput(input) }
                    if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
                    session.commitConfiguration()
                    session.startRunning()
                    continuation.resume(returning: true)
                } catch {
                    session.commitConfiguration()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func stop() {
        let session = self.session
        sessionQueue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Capture a single still photo.
    func capturePhoto() async throws -> UIImage {
        guard isAvailable else { throw CameraError.unavailable }
        let photoOutput = self.photoOutput
        return try await withCheckedThrowingContinuation { continuation in
            self.captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            sessionQueue.async { [weak self] in
                guard let self else { return }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    /// Resume the pending continuation exactly once, then clear it.
    fileprivate func finishCapture(with result: Result<UIImage, Error>) {
        switch result {
        case .success(let image):
            captureContinuation?.resume(returning: image)
        case .failure(let error):
            captureContinuation?.resume(throwing: error)
        }
        captureContinuation = nil
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
        // Extract a plain, Sendable value (Data) off the delegate thread, then
        // hop to the main actor to resume the continuation.
        let result: Result<UIImage, Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            result = .success(image)
        } else {
            result = .failure(CameraError.captureFailed)
        }
        Task { @MainActor [weak self] in
            self?.finishCapture(with: result)
        }
    }
}
