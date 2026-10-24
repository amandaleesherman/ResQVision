# ResQVision — Guidance Engine

The "brain" between the camera/vision step and the first-aid instructions
screen. It takes an **Observation** (text + optional labels describing what the
camera saw) and returns structured, **source-cited** first-aid guidance.

This component implements [`resqvision-guidance-engine-spec.md`](../resqvision-guidance-engine-spec.md).

## Safety guarantees (by design)

- **Never looks at images.** Input is text + labels only.
- **Only outputs text that exists in the curated knowledge base.** The engine
  never writes or paraphrases medical instructions.
- **No diagnosis, no medications, no dosages.**
- **Emergency-first.** A red-flag check runs *before* retrieval; if anything
  suggests a life-threatening situation, `emergency.call_911` is `true` and
  the response always carries emergency escalation — even if retrieval fails.
- **Fails safe.** Any internal error degrades to the general fallback with
  emergency guidance, never an HTTP 500 with no guidance.

> ⚠️ The medical content in `data/knowledge_base.json` is currently
> **`"TODO: fill from source"` placeholders**. A human on the team must fill in
> every step/warning/excerpt/URL from reputable sources (American Red Cross,
> Mayo Clinic, NHS, CDC) and set `reviewed: true` only after verifying each URL.
> The engine logs a warning for every `reviewed: false` entry.

## Project layout

```
guidance-engine/
├── data/
│   ├── knowledge_base.json   # curated first-aid entries (placeholders for now)
│   ├── red_flags.json        # emergency trigger terms
│   └── eval_cases.json       # evaluation observations + expected results
├── engine/
│   ├── models.py             # Observation + GuidanceResponse (pydantic)
│   ├── _compat_models.py     # stdlib fallback used only when pydantic is absent
│   ├── normalize.py          # text cleanup + synonyms
│   ├── retrieve.py           # KB loading + keyword/category scoring
│   ├── safety.py             # red-flag detection, provenance, final checks
│   └── guidance.py           # get_guidance() — main entry point
├── api/main.py               # FastAPI app
├── eval/run_eval.py          # runs eval_cases.json -> eval_results.json
├── tests/                    # pytest (retrieve, safety, api)
└── requirements.txt
```

## Setup & run

```bash
cd guidance-engine
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# Run the API (CORS enabled for web/Expo/iOS clients)
uvicorn api.main:app --reload
```

Run tests and the evaluation:

```bash
python -m pytest -q
python eval/run_eval.py        # writes eval/eval_results.json
```

> **Offline note:** `engine/models.py` normally uses **pydantic** (pinned in
> `requirements.txt`). If pydantic cannot be installed (e.g. an offline
> sandbox), it transparently falls back to a small stdlib shim
> (`_compat_models.py`) so the engine and tests still run. On your Mac / CI,
> pydantic is used directly and the shim is never imported.

## HTTP API

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/guidance` | Main call. Body = Observation JSON → GuidanceResponse JSON. |
| `GET` | `/categories` | Lists supported injury categories. |
| `GET` | `/health` | `{"status":"ok","kb_entries":N}` |
| `GET` | `/eval` | Latest evaluation results (for the safety dashboard). |

### For Person 1 (iOS app) — copy-paste examples

**curl:**

```bash
curl -s -X POST http://localhost:8000/guidance \
  -H "Content-Type: application/json" \
  -d '{
    "source": "vision_model",
    "is_sample": false,
    "description": "Open cut on left forearm, blood soaking through cloth",
    "labels": [{"name": "bleeding", "confidence": 0.91}],
    "body_location": "forearm",
    "uncertainties": ["depth of wound cannot be determined"]
  }'
```

**Swift (URLSession) — matches the `Observation` contract the app builds:**

```swift
struct Label: Codable { let name: String; let confidence: Double }

struct Observation: Codable {
    let source: String            // "vision_model" | "sample" | "user_text"
    let is_sample: Bool
    let description: String
    let labels: [Label]
    let body_location: String?
    let uncertainties: [String]
}

func fetchGuidance(_ observation: Observation) async throws -> Data {
    var req = URLRequest(url: URL(string: "http://localhost:8000/guidance")!)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONEncoder().encode(observation)
    let (data, _) = try await URLSession.shared.data(for: req)
    return data   // decode into a GuidanceResponse Codable (see Section 5.4)
}
```

### Input: `Observation` (spec §5.3)

| Field | Type | Required | Notes |
|---|---|---|---|
| `source` | `"vision_model"`\|`"sample"`\|`"user_text"` | yes | Where the observation came from |
| `is_sample` | bool | yes | `true` for demo/hard-coded observations |
| `description` | string | yes | May be empty if `labels` exist |
| `labels` | `[{name, confidence 0–1}]` | no | From the vision model |
| `body_location` | string | no | e.g. "hand", "head", "leg" |
| `uncertainties` | `[string]` | no | What the vision step could not determine |

### Output: `GuidanceResponse` (spec §5.4)

Always includes: `emergency` (with `call_911`), `category`, `match_confidence`
(`high`/`medium`/`low`/`none`), `title`, `steps[]` (each with a `source_id`
present in `sources[]`), `warnings[]`, `sources[]`, `observation_provenance`
(sample inputs labeled `"SAMPLE DATA — not a real camera analysis."`),
`cannot_determine[]`, `follow_up_questions[]`, `disclaimer`, `is_fallback`,
`engine_version`.

## Evaluation targets (spec §10)

| Metric | Target | Current (placeholder KB) |
|---|---|---|
| `category_accuracy` | ≥ 85% | 100% |
| `red_flag_recall` | **100%** | 100% |
| `citation_coverage` | **100%** | 100% |
| `fallback_correctness` | ≥ 90% | 100% |
| `unsupported_text_rate` | **0%** | 0% |
| `sample_label_correctness` | **100%** | 100% |

Metrics are measured against retrieval behavior; they remain valid once the
team fills in the knowledge-base content (step text comes verbatim from the KB,
so `unsupported_text_rate` stays 0%).

## What the team still needs to do

1. Fill `data/knowledge_base.json` content fields from verified sources; set
   `reviewed: true` per entry after checking every URL.
2. Review `data/red_flags.json` against those sources.
3. Review the expected values in `data/eval_cases.json`.
