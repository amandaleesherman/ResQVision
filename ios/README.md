# ResQVision — iOS App (Workstream A)

Native SwiftUI prototype: a **camera-first** emergency first-aid assistant.
Capture or pick a photo of an injury → extract any printed text on-device
(OCR) → get structured, source-cited first-aid guidance on a response screen.

- **Target:** iOS 17.0+
- **Dependencies:** none (pure SwiftUI + Apple frameworks: AVFoundation,
  PhotosUI, Vision)
- **AI analysis:** behind the `AnalysisService` protocol. A **mock**
  implementation is wired in now so the full flow works with no backend. The
  real vision endpoint is swapped in later in one place — no UI changes.

## Requirements

- A Mac with **Xcode 16+** (the project uses the Xcode 16 "synchronized
  folders" project format, `objectVersion = 77`).
- iOS 17 Simulator (bundled with Xcode) for UI + photo-library testing.
- A physical iPhone + a free Apple Developer account to test **live camera
  capture** (the Simulator has no camera).

## Open & run

1. Open `ios/ResQVision.xcodeproj` in Xcode.
2. Select an **iOS 17 Simulator** (e.g. iPhone 15) as the run destination.
3. Press **Run** (⌘R).

Because the project uses a file-system–synchronized group, every `.swift` file
under `ResQVision/` is included automatically — you do not add files to the
target manually.

## What works today (mock analysis)

- **Camera-first landing.** On a device, a live camera preview with a Capture
  button. On the Simulator / when camera permission is denied, it gracefully
  explains why and makes **Photo Library** the primary action — so the whole
  flow is testable on the Simulator.
- **Photo capture & library selection** → a confirm screen ("Use this photo?").
- **On-device OCR** (`VNRecognizeTextRequest`) runs on the chosen image; the
  recognized text is passed along as context. No text found is handled
  gracefully.
- **Analysis** via `MockAnalysisService`, which returns canned `GuidanceResponse`
  data. Every mock result is flagged **SAMPLE DATA** and contains **no real
  medical instructions** (placeholder step text only).
- **Response screen:** emergency "Call 911" banner first (with a tap-to-call
  link), numbered steps, warnings, "what we couldn't tell", follow-up checks,
  tappable sources, and the disclaimer.

> Testing the camera on the Simulator: the Simulator has no camera, so use the
> **Photo Library** button. Drag image files onto the Simulator window to add
> them to its Photos app first.

## Project structure

```
ios/
├── ResQVision.xcodeproj
└── ResQVision/
    ├── ResQVisionApp.swift          # @main entry point -> LandingView
    ├── Models/
    │   ├── Observation.swift        # input contract (mirrors guidance engine §5.3)
    │   └── GuidanceResponse.swift   # output contract (mirrors guidance engine §5.4)
    ├── Services/
    │   ├── AnalysisService.swift    # protocol (the AI seam)
    │   ├── MockAnalysisService.swift# canned results used now
    │   └── OCRService.swift         # on-device Vision OCR (real)
    ├── Camera/
    │   ├── CameraController.swift    # AVCaptureSession wrapper (simulator-safe)
    │   └── CameraPreview.swift       # SwiftUI live-preview wrapper
    ├── Views/
    │   ├── CaptureViewModel.swift    # flow state: capture -> OCR -> analyze
    │   ├── LandingView.swift         # camera-first entry + library fallback
    │   ├── PhotoConfirmView.swift    # "Use this photo?" step
    │   └── ResponseView.swift        # emergency-first guidance screen
    └── Assets.xcassets/
```

## The AI seam (how the real endpoint plugs in later)

The app depends only on this protocol:

```swift
protocol AnalysisService {
    func analyze(image: UIImage, ocrText: String) async throws -> GuidanceResponse
}
```

To go live, add a `RemoteAnalysisService: AnalysisService` that:
1. Sends the image to a vision-capable model, instructing it to return a
   **neutral description + labels only** (no treatment advice), then
2. Builds an `Observation` and POSTs it to the guidance engine's `/guidance`
   endpoint (Workstream B), decoding the JSON straight into `GuidanceResponse`.

Then change one line in `LandingView`:

```swift
// from:
@StateObject private var model = CaptureViewModel(analysis: MockAnalysisService())
// to:
@StateObject private var model = CaptureViewModel(analysis: RemoteAnalysisService(...))
```

No other UI code changes. The `Observation` / `GuidanceResponse` Codable types
already match the backend JSON contract exactly.

> ⚠️ Do not embed an API key in the app. The vision call should go through a
> server-side proxy (alongside the guidance engine) so the key stays off the
> device. The endpoint and image-input support still need to be confirmed.

## Permissions

Declared as build settings (`GENERATE_INFOPLIST_FILE = YES`):
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`

## Status

- [x] Camera-first landing with simulator/permission fallback
- [x] Photo capture + library selection + confirm
- [x] On-device OCR
- [x] Mock analysis service behind a protocol
- [x] Emergency-first response screen with cited sources
- [ ] Real vision endpoint (`RemoteAnalysisService`) — pending endpoint confirmation
- [ ] Wound-classification accuracy evaluation (needs labeled test images)
```
