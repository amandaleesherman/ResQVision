# EmergencyFirst — Project Steering

EmergencyFirst is an iOS first-aid assistant built for the HACKACHUSETTS hackathon.
The user takes or selects a photo of a situation and receives first-aid guidance.

This file is Kiro steering: it gives persistent context about the project so
future sessions understand the architecture without re-deriving it.

## Hackathon requirement

- We must use Kiro. Always preserve the `.kiro/` directory at the project root.
- Never add `.kiro/` to `.gitignore`. It must stay tracked in git.

## Xcode project facts

- Project bundle: `EmergencyFirst.xcodeproj` (display name "EmergencyFirst").
- The build target is internally named **`MyApp`** and the source folder is
  **`MyApp/`**. The project uses a file-system-synchronized group, so any
  `.swift` file placed under `MyApp/` is compiled automatically — no need to
  register files in `project.pbxproj`.
- Keep the `MyApp/` folder name; it must match `path = MyApp;` in the project.
- Camera permission string (`NSCameraUsageDescription`) is set as a build
  setting in `project.pbxproj` (both Debug and Release). The photo library
  uses `PHPickerViewController`, which needs no permission.

## Team split

- Person 1 (this workspace's owner): SwiftUI interface, camera capture,
  photo-library selection, navigation, and integration with the guidance engine.
- A teammate owns the real guidance engine.

## Architecture

Single state-driven flow. `AppState` is the one source of truth; `RootView`
switches screens based on `appState.screen`:

    home → (camera OR library) → preview → loading → results → home

Source layout under `MyApp/`:

- `MyAppApp.swift` — `@main` entry point.
- `RootView.swift` — owns `AppState`, switches between screens.
- `Models/AppState.swift` — `@Observable` state + flow helpers + `runAnalysis()`.
- `Models/GuidanceResult.swift` — structured result (title, steps, isSevere).
- `Screens/` — `HomeView`, `PhotoPreviewView`, `LoadingView`, `ResultsView`.
- `Camera/` — `CameraPicker` (UIImagePickerController), `PhotoLibraryPicker`
  (PHPickerViewController).
- `Services/GuidanceEngine.swift` — the `GuidanceEngine` protocol (the contract
  between the UI and the engine) plus `GuidanceError`.
- `Services/StubGuidanceEngine.swift` — placeholder engine used until the real
  one is ready.

## Guidance engine boundary

The UI only talks to the `GuidanceEngine` protocol. The teammate's real engine
conforms to `GuidanceEngine` and is swapped in with a single line change:

    // in AppState
    var engine: GuidanceEngine = StubGuidanceEngine()   // ← replace the stub here

No view code changes when the real engine lands.

## Build / verify

- Build for a simulator, e.g.:
  `xcodebuild -project EmergencyFirst.xcodeproj -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build`
- The camera only works on a real device; the simulator falls back to the
  photo library automatically.
- Deployment target is iOS 27.0, so a physical device must run iOS 27+.

## AI pipeline decisions (vision + RAG)

Three components, each with one job (do not blur them):

1. Vision model — extracts *observable* features from the wound photo only.
   Model: `gemini-3.8-flash` (Google Gemini API, multimodal, GA).
   Returns a small structured JSON object (WoundAnalysis), never a diagnosis.
2. RAG — retrieves first-aid guidance from trusted medical sources ONLY:
   WebMD, MedlinePlus, American Red Cross. No other sources.
3. Guidance engine — combines vision features + retrieved guidance into
   cautious, evidence-grounded instructions. It must NOT claim to diagnose a
   condition from an image; it frames output as general first-aid guidance and
   defers to professional care / emergency services when appropriate.

### API key handling (IMPORTANT — safety)

- NEVER hardcode the Gemini API key in the app; an iOS binary ships to every
  user and the key can be extracted.
- Current approach (prototype): key lives in `MyApp/Services/Secrets.swift`
  (an `enum Secrets { static let geminiAPIKey }`), which is gitignored. A
  committed `Secrets.swift.template` documents the format. The file-system
  synchronized `MyApp/` group compiles it automatically — no pbxproj edits.
- Before any PUBLIC demo or release: move the key behind a server-side proxy so
  it never ships in the app. The Gemini client's base URL is the only thing
  that changes for that switch.

### Guidance / medical safety

- Always show that this is general first-aid guidance, not a medical diagnosis.
- Emphasize calling emergency services for severe situations.
- The vision model reports uncertainty; low confidence or poor image quality
  must be surfaced, not hidden.
