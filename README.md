# ResQVision 🚨📱
### AI-Assisted Emergency Response & First Aid

**See the situation. Understand the risks. Take the next step.**

ResQVision is an iOS emergency-response prototype. Point your phone at an
injury, and the app extracts any on-device text, asks an analysis service what
it's looking at, and returns **source-cited, emergency-first** first-aid
guidance — leading with "Call 911" whenever the situation looks life-threatening.

> ⚠️ **Medical Disclaimer:** ResQVision is a prototype, not a medical device or
> a substitute for professional care. AI-generated assessments may be
> inaccurate. In a life-threatening emergency, call 911 (US) or your local
> emergency number. Never delay emergency care to use this app.

---

## 🧭 How it works

```
 📸 Capture / pick a photo        (iOS app · AVFoundation + PhotosUI)
          │
          ▼
 🔤 On-device OCR                 (iOS app · Vision / VNRecognizeTextRequest)
          │  extracts any printed text (labels, bottles) — runs offline
          ▼
 🧠 Analysis service              (AnalysisService protocol — mock today)
          │  image + OCR text → a neutral Observation (description + labels)
          ▼
 🩹 Guidance engine               (Python · FastAPI · RAG over a curated KB)
          │  Observation → emergency check → retrieval → cited first-aid steps
          ▼
 📋 Response screen               (iOS app)
     Emergency banner first · numbered steps · warnings · tappable sources
```

Two cooperating pieces, developed in parallel:

| Component | Where it lives | Runtime | Status |
|---|---|---|---|
| **iOS app** (camera, OCR, UI) | [`ios/`](ios/) | On-device (Swift/SwiftUI) | ✅ Working with a mock analysis service |
| **Guidance engine** (RAG + safety) | [`guidance-engine/`](guidance-engine/) | Backend (Python/FastAPI) | ✅ Working; medical content pending human review |

---

## 🛡️ Safety model (the most important part)

This is a medical-adjacent app, so the design deliberately limits what the AI
is allowed to do:

- **No invented medical advice.** The guidance engine only returns first-aid
  text that exists **verbatim in a human-curated knowledge base**. It cannot
  author or paraphrase instructions.
- **Every step is cited.** Each step links to its source (American Red Cross,
  Mayo Clinic, NHS, CDC). The engine refuses entries whose steps lack a valid
  source, and flags any entry not yet human-reviewed.
- **Emergency-first.** A red-flag check runs *before* any analysis; if anything
  suggests a life-threatening situation, "Call 911" is shown and is **never**
  blocked by a failure elsewhere in the pipeline.
- **Honest uncertainty.** Vague inputs fall back to general safety guidance and
  clarifying questions instead of guessing.
- **Sample data is labeled.** Mock/demo results are clearly marked
  "SAMPLE DATA — not a real camera analysis" and contain no real medical text.

> The current knowledge base ships with `"TODO: fill from source"`
> placeholders. The team fills and verifies every step/URL from reputable
> sources before an entry is marked `reviewed: true`.

---

## 🛠️ Tech stack

| Area | Technology |
|---|---|
| iOS app | Swift, SwiftUI (iOS 17+), no third-party dependencies |
| Camera & media | AVFoundation, PhotosUI |
| On-device OCR | Vision (`VNRecognizeTextRequest`) |
| Guidance engine | Python 3.11, FastAPI, Uvicorn, pydantic |
| Retrieval | Keyword/category scoring (pure Python — no ML needed for v1) |
| Tooling | Xcode 16+, pytest, Git/GitHub, Kiro |

---

## 📁 Repository layout

```
ResQVision/
├── ios/                     # Native SwiftUI app (Workstream A)
│   └── ResQVision/          # Models, Services, Camera, Views
├── guidance-engine/         # FastAPI guidance/RAG backend (Workstream B)
│   ├── engine/              # models, normalize, retrieve, safety, guidance
│   ├── data/                # knowledge_base.json, red_flags.json, eval_cases.json
│   ├── api/                 # FastAPI app
│   ├── eval/                # accuracy/safety evaluation harness
│   └── tests/               # pytest
└── README.md
```

> **Note on branches:** the app and the engine are developed on separate feature
> branches (`iOS-app-and-camera`, `RAG-medical-info`) and merged into `main` via
> pull requests. A given branch may contain only one component's code.

---

## 🚀 Getting started

### iOS app (`ios/`)

**Requirements:** a Mac with **Xcode 16+**, an iOS 17 Simulator, and (for live
camera testing) a physical iPhone with a free Apple Developer account.

```bash
git clone https://github.com/amandaleesherman/ResQVision.git
cd ResQVision
open ios/ResQVision.xcodeproj
```

Pick an iOS 17 Simulator and press **Run** (⌘R). The Simulator has no camera, so
use the **Photo Library** button there (drag an image onto the Simulator window
to add it to Photos first). Camera capture is tested on a real iPhone.

The app runs end-to-end today against a **mock** analysis service — no backend or
API key required. See [`ios/README.md`](ios/README.md) for details and how the
real analysis service plugs in.

### Guidance engine (`guidance-engine/`)

**Requirements:** Python 3.11+.

```bash
cd guidance-engine
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

uvicorn api.main:app --reload     # start the API
python -m pytest -q                # run tests
python eval/run_eval.py            # run the accuracy/safety evaluation
```

Endpoints: `POST /guidance`, `GET /categories`, `GET /health`, `GET /eval`.
See [`guidance-engine/README.md`](guidance-engine/README.md) for the full
input/output contract and copy-paste examples.

---

## 🔌 How the pieces connect

The app depends only on a small protocol:

```swift
protocol AnalysisService {
    func analyze(image: UIImage, ocrText: String) async throws -> GuidanceResponse
}
```

Today that's a `MockAnalysisService`. To go live, a `RemoteAnalysisService`
will (1) send the image to a vision-capable model that returns a **neutral
description + labels only** (no treatment advice), then (2) POST that
`Observation` to the guidance engine's `/guidance` endpoint. The app's
`Observation` / `GuidanceResponse` types already match the engine's JSON
contract, so the response decodes directly — swapping the service is a one-line
change with no UI edits.

> 🔐 No API key should ship in the app. The vision call will be routed through a
> server-side proxy alongside the guidance engine.

---

## 📊 Measuring accuracy

Two different things get measured:

- **Solution quality** (done, in `guidance-engine/eval/`): does the engine pick
  the right category, flag every true emergency, and cite every step? Current
  evaluation hits its targets (red-flag recall 100%, citation coverage 100%,
  no unsupported step text).
- **Wound classification** (next): how often the vision step describes the
  injury correctly. This needs a set of labeled example photos and a dedicated
  evaluation harness.

---

## 🗺️ Roadmap

- [x] Camera-first landing with capture + photo-library selection
- [x] On-device OCR (`VNRecognizeTextRequest`)
- [x] Analysis behind a protocol with a mock implementation
- [x] Emergency-first response screen with cited sources
- [x] Guidance engine: retrieval, red-flag safety, fallback, citations
- [x] Guidance-engine evaluation harness and tests
- [ ] Fill & human-verify the first-aid knowledge base content
- [ ] `RemoteAnalysisService` + server-side vision proxy (pending endpoint)
- [ ] Wound-classification accuracy evaluation (needs labeled images)
- [ ] Usability testing across emergency scenarios

---

## 🔒 Privacy & safety

- Request camera access only when needed; OCR runs on-device.
- Minimize retention of injury photos and personal/medical data.
- Protect any image/data sent to external analysis services.
- Never present uncertain AI output as a confirmed diagnosis.
- Always provide emergency-escalation guidance and communicate limitations.

## 👥 Team

Built by our hackathon team with a focus on AI, mobile development,
accessibility, and emergency response.

## 🤝 Contributing

Contributions, feedback, and ideas are welcome. Open an issue to discuss a
proposed change before submitting a pull request.

## 📄 License

A license has not yet been selected and will be added once the team decides on
appropriate terms.

---

**ResQVision — AI-assisted guidance for moments that matter.**
