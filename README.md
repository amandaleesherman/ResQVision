# ResQVision 🚨📱
### AI-Assisted Emergency Response & First Aid
**See the situation. Understand the risks. Take the next step.**

ResQVision is an iOS emergency-response app that helps people act in urgent moments. Photograph a wound and, in seconds, get clear, source-grounded first-aid steps — with transparent limits about what a photo can and can't tell.

It combines a native SwiftUI app, a vision model that describes *observable* features (never a diagnosis), and retrieval of first-aid guidance from trusted medical sources.

> ⚠️ **Medical Disclaimer:** ResQVision is a prototype, **not** a medical device or a substitute for professional care. AI output may be inaccurate. In a life-threatening emergency call **911** (US) or your local emergency number. **Never delay emergency care to use this app.**

---

## ✨ Features

- 📸 **Capture or choose a photo** — custom camera built on **AVFoundation** (live preview, front/back switching, permission handling), or pick from the library via **PhotoKit (PHPicker)**.
- 🧠 **Observation, not diagnosis** — a **Google Gemini** vision model reports only visible features (apparent wound type, redness, visible bleeding, image quality) and its own uncertainty. It is explicitly instructed not to diagnose.
- 🩹 **Clear first-aid steps** — concise, actionable guidance written to be understood under stress.
- 📚 **Source-grounded guidance** — recommendations are drawn from three trusted sources only — **WebMD, MedlinePlus, American Red Cross** — and cited on screen.
- 🧰 **Supplies & longer-term care** — suggested tools/supplies (e.g. gauze, tourniquet) with "how to use" steps, plus longer-term care notes.
- 🚑 **One-tap emergency call** — a call button on both the home and results screens; the severity banner urges professional care when warranted.
- ⚡ **Emergency-grade reliability** — results in ~1–2 seconds, automatic retry on short timeouts, and graceful fallback to trusted guidance if the AI is unreachable.

---

## 🎯 The Problem

In an emergency, people struggle to judge how serious an injury is, find trustworthy first-aid steps, and decide what to do next. Stress and limited medical knowledge make it worse. ResQVision explores how AI-assisted mobile tech can surface understandable guidance while steering people toward appropriate professional care.

---

## 💡 How It Works

Three components, each with **one job** — which is what keeps it safe:

1. **Capture** — the user photographs the injury on their iPhone.
2. **Vision** — the photo goes to **Gemini** (`gemini-3.5-flash-lite`), which returns *observable features* as structured JSON. No diagnosis.
3. **Retrieval (RAG)** — matching first-aid guidance is pulled from the three approved sources.
4. **Synthesis** — the features + retrieved guidance are combined into cautious, grounded steps with citations, always deferring to professional care when appropriate.

The app supports decision-making; it does not independently diagnose injuries or prescribe treatment.

---

## 🛠️ Tech Stack

| Technology | Purpose |
|---|---|
| **Swift / SwiftUI** | Native iOS app and UI |
| **Xcode 27 (iOS)** | Build, test, simulate |
| **AVFoundation** | Custom camera (`AVCaptureSession` + live preview) |
| **PhotoKit (`PHPickerViewController`)** | Photo-library selection (no permission prompt) |
| **Swift Concurrency** | `async/await`, `@Observable` app state |
| **Google Gemini API** | Vision + synthesis — `gemini-3.5-flash-lite` via `generateContent` (`URLSession`) |
| **Retrieval (RAG)** | Curated first-aid corpus: WebMD, MedlinePlus, American Red Cross |
| **Python guidance engine** | Teammate service integrated behind a Swift protocol boundary |
| **Git & GitHub** | Version control & collaboration |
| **Kiro** | AI-assisted development and `.kiro/` steering |

---

## 🏗️ Architecture

```
iPhone camera / photo library
          |
          v
   Image capture & preview          (AVFoundation / PHPicker)
          |
          v
   Vision model (Gemini)            observable features only, no diagnosis
          |
          v
   Retrieval (RAG)                  WebMD · MedlinePlus · American Red Cross
          |
          v
   Synthesis                        cautious, grounded steps + citations
          |
          v
   Results UI                       steps, supplies, longer-term care,
                                    sources, one-tap emergency call
```

The UI talks to the guidance layer through a Swift **protocol boundary** (`GuidanceEngine`), so the vision+RAG implementation (or a teammate's engine) can be swapped without changing any views.

---

## 🚀 Getting Started

### Prerequisites
- A Mac with **Xcode 27** (or a version matching the project's iOS deployment target) and the iOS SDK.
- An **iPhone running iOS 27+** for the camera (the camera does not work in the Simulator; the app falls back to the photo library there).
- A **Google Gemini API key** — https://aistudio.google.com/apikey
- Git and a GitHub account.

### Installation
```bash
git clone https://github.com/amandaleesherman/ResQVision.git
cd ResQVision
```

### Add your API key (required)
The key is read from a **gitignored** file so it never gets committed. Copy the template and paste your key:
```bash
cp MyApp/Services/Secrets.swift.template MyApp/Services/Secrets.swift
```
Then open `MyApp/Services/Secrets.swift` and replace the placeholder:
```swift
enum Secrets {
    static let geminiAPIKey = "YOUR_GEMINI_API_KEY"
}
```
> `Secrets.swift` is listed in `.gitignore` — **never commit your key.** For a public release, move the key behind a server-side proxy instead of shipping it in the app.

### Run
1. Open `EmergencyFirst.xcodeproj` in Xcode.
2. In **Signing & Capabilities**, select your development **Team**.
3. Choose your iPhone (or a Simulator) as the run destination and press **Run** (⌘R).
4. First launch on a device may require trusting the developer profile: **Settings → General → VPN & Device Management**.

---

## 🔒 Privacy & Safety

- Camera access is requested only when needed, with a graceful "enable in Settings" fallback if denied.
- The photo-library picker (PHPicker) runs out of process and needs no library permission.
- The Gemini API key is kept out of version control (gitignored `Secrets.swift`).
- Vision output is framed as **observations, not a diagnosis**, and uncertainty / poor image quality is surfaced rather than hidden.
- Guidance is grounded in reviewed sources and always points toward professional care for serious situations.

---

## 🗺️ Roadmap

- [x] iOS app shell, navigation, and emergency flow
- [x] Camera capture (AVFoundation) + photo-library picker
- [x] Gemini vision analysis (observable features, no diagnosis)
- [x] RAG over WebMD / MedlinePlus / American Red Cross with citations
- [x] One-tap emergency call + severity emphasis
- [x] Supplies/tools + longer-term care guidance
- [x] Retry, timeouts, and graceful fallback for reliability
- [ ] Move the API key behind a server-side proxy
- [ ] Expand and formally review the first-aid knowledge base
- [ ] Accessibility pass (VoiceOver, Dynamic Type) and usability testing
- [ ] Model evaluation for reliability and safety

---

## 👥 Team

Built by our hackathon team across iOS, AI, and the guidance engine, with a focus on accessibility and responsible, source-grounded emergency guidance.

## 🤝 Contributing

Open an issue to discuss a proposed change before submitting a pull request.

## 📄 License

A license has not yet been selected; terms will be added by the project team.

---

*ResQVision — AI-assisted guidance for moments that matter.*
