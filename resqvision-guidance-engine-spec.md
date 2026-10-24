# ResQVision — Guidance Engine Spec (Person 2)

> Paste this whole file into Kiro (or save it as `.kiro/specs/guidance-engine/requirements.md`) and use the prompt in Section 12 to start.

---

## 1. What this component does

The guidance engine is the "brain" between the camera and the instructions screen.

```
[Camera / vision model]  →  Observation (text + labels)  →  [GUIDANCE ENGINE]  →  Guidance (steps + sources + warnings)  →  [App UI]
       Person 1                                                  Person 2 (me)                                              Person 1
```

**Input:** a text description of what the camera saw (plus optional labels).
**Output:** short, ordered first-aid steps, each tied to a cited source, plus emergency warnings.

**Key assumption:** the image-to-text step already happened. This engine never looks at images. It only reads the observation text, so it can be built and tested entirely on Windows with no Xcode or phone.

---

## 2. Goals and non-goals

### Goals
- Return relevant first-aid steps from a **curated, human-checked library**, never invented text.
- Every step is traceable to a source (publisher, URL, short excerpt).
- **Emergency-first:** if anything suggests a life-threatening situation, the response leads with "Call 911" before any steps.
- Handle uncertain or vague observations safely (fall back to general guidance and say what can't be determined).
- Clearly mark when an observation is **sample/demo data** versus a **real vision result**.
- Provide a simple, stable interface for Person 1 (Python function + HTTP endpoint).
- Produce evaluation results for the safety dashboard.

### Non-goals (for the hackathon)
- No diagnosis. The engine never says "you have X."
- No medication names or dosages.
- No image processing.
- No LLM-generated medical instructions. (An LLM may only be used later, as a stretch, to *rephrase* already-retrieved steps, with a check that nothing new was added.)

---

## 3. Tech stack

- **Language:** Python 3.11+
- **Core engine:** pure Python, standard library only (no ML needed for v1)
- **API:** FastAPI + Uvicorn (so any app, whether web, React Native/Expo, or iOS, can call it over HTTP)
- **Data:** JSON files in `data/`
- **Tests:** pytest
- **Stretch:** embeddings (e.g. `sentence-transformers` or Amazon Bedrock) for fuzzy matching

---

## 4. File structure

```
guidance-engine/
├── data/
│   ├── knowledge_base.json       # curated first-aid entries (Section 6)
│   ├── red_flags.json            # emergency trigger terms (Section 7)
│   └── eval_cases.json           # test observations + expected results (Section 10)
├── engine/
│   ├── __init__.py
│   ├── models.py                 # dataclasses / pydantic models for input + output
│   ├── normalize.py              # text cleanup, synonyms
│   ├── retrieve.py               # keyword/category scoring
│   ├── safety.py                 # red-flag detection, fallback, provenance labels
│   └── guidance.py               # get_guidance() — the main entry point
├── api/
│   └── main.py                   # FastAPI app
├── eval/
│   └── run_eval.py               # runs eval_cases.json → writes eval_results.json
├── tests/
│   ├── test_retrieve.py
│   ├── test_safety.py
│   └── test_api.py
├── requirements.txt
└── README.md
```

---

## 5. Interface contract (what Person 1 calls)

### 5.1 Python function

```python
from engine.guidance import get_guidance

response = get_guidance(observation)   # Observation → GuidanceResponse
```

### 5.2 HTTP endpoints

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/guidance` | Main call. Body = Observation JSON. Returns GuidanceResponse JSON. |
| `GET` | `/categories` | Lists supported injury categories. |
| `GET` | `/health` | Returns `{"status": "ok", "kb_entries": N}`. |
| `GET` | `/eval` | Returns latest evaluation results (for the dashboard). |

CORS must be enabled so a web/Expo app can call it.

### 5.3 Input: `Observation`

```json
{
  "source": "vision_model",
  "is_sample": false,
  "description": "Open cut on left forearm, bright red blood flowing steadily, blood soaking through cloth",
  "labels": [
    { "name": "laceration", "confidence": 0.82 },
    { "name": "bleeding", "confidence": 0.91 }
  ],
  "body_location": "forearm",
  "uncertainties": ["depth of wound cannot be determined", "cannot see if object is embedded"]
}
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `source` | `"vision_model"` \| `"sample"` \| `"user_text"` | yes | Where the observation came from |
| `is_sample` | bool | yes | `true` for demo/hard-coded observations |
| `description` | string | yes | Free text of what was seen. Can be empty if labels exist. |
| `labels` | list of `{name, confidence 0–1}` | no | From the vision model |
| `body_location` | string | no | e.g. "hand", "head", "leg" |
| `uncertainties` | list of strings | no | Things the vision step said it couldn't determine |

### 5.4 Output: `GuidanceResponse`

```json
{
  "emergency": {
    "call_911": true,
    "reason": "Heavy or spurting bleeding detected",
    "message": "Call 911 now. Start these steps while you wait or have someone else call."
  },
  "category": "severe_bleeding",
  "match_confidence": "high",
  "title": "Control severe bleeding",
  "steps": [
    { "order": 1, "text": "Call 911 or have someone call.", "source_id": "src_redcross_bleeding" },
    { "order": 2, "text": "Press firmly on the wound with a clean cloth or bandage.", "source_id": "src_redcross_bleeding" }
  ],
  "warnings": ["Do not remove an object stuck in the wound."],
  "sources": [
    {
      "id": "src_redcross_bleeding",
      "publisher": "American Red Cross",
      "title": "<page title>",
      "url": "<verified URL>",
      "excerpt": "<short excerpt, under 15 words>",
      "retrieved_date": "2026-10-24"
    }
  ],
  "observation_provenance": {
    "source": "vision_model",
    "is_sample": false,
    "label": "Based on camera analysis — may be incomplete"
  },
  "cannot_determine": ["depth of wound cannot be determined"],
  "follow_up_questions": ["Is the bleeding slowing after 10 minutes of pressure?"],
  "disclaimer": "This is first-aid guidance, not a medical diagnosis. When in doubt, call 911.",
  "is_fallback": false,
  "engine_version": "0.1.0"
}
```

Rules for the output:
- `emergency` is **always present** (with `call_911: false` if no red flags).
- Every item in `steps` must have a `source_id` that exists in `sources`.
- `match_confidence` is `"high"`, `"medium"`, `"low"`, or `"none"`.
- If `is_sample` is true, `observation_provenance.label` must say **"SAMPLE DATA — not a real camera analysis."**

---

## 6. Knowledge base schema (`data/knowledge_base.json`)

Each entry:

```json
{
  "id": "severe_bleeding",
  "category": "severe_bleeding",
  "title": "Control severe bleeding",
  "keywords": ["bleeding", "blood", "laceration", "deep cut", "gash", "spurting", "soaking"],
  "body_locations": [],
  "red_flags": ["spurting", "won't stop", "soaking through", "pool of blood", "amputation"],
  "steps": [
    { "order": 1, "text": "...", "source_id": "src_redcross_bleeding" }
  ],
  "warnings": ["..."],
  "do_not": ["..."],
  "follow_up_questions": ["..."],
  "sources": [
    {
      "id": "src_redcross_bleeding",
      "publisher": "American Red Cross",
      "title": "...",
      "url": "...",
      "excerpt": "...",
      "retrieved_date": "YYYY-MM-DD"
    }
  ],
  "reviewed": false
}
```

### Starter categories (aim for 8–10)

| id | Covers |
|---|---|
| `severe_bleeding` | heavy, spurting, or uncontrolled bleeding |
| `minor_cut_scrape` | small cuts, scrapes, abrasions |
| `burn_thermal` | heat burns, scalds |
| `burn_chemical` | chemical on skin |
| `nosebleed` | nosebleeds |
| `sprain_fracture` | swelling, deformity, suspected broken bone |
| `head_injury` | bump or wound on the head |
| `bite_sting` | animal bites, insect stings |
| `eye_injury` | object or chemical in eye |
| `general_unknown` | **fallback** — general safety + "call 911 if serious" |

### Content rules (important)
- **A human on the team writes and checks every step**, paraphrasing the source in plain, short sentences. Kiro must **not** invent first-aid instructions or URLs. Kiro should create the schema and fill content fields with `"TODO: fill from source"` placeholders.
- Every `url` must be opened and verified by a person. Set `reviewed: true` only after that.
- Keep `excerpt` short (under 15 words) — it's evidence, not a copy of the page.
- Steps should be 1 sentence each, max ~15 words, readable aloud.
- Reputable sources: American Red Cross, Mayo Clinic first aid, NHS, CDC.
- The engine refuses to load entries with missing `source_id`s and logs a warning for entries with `reviewed: false`.

---

## 7. Red flags (`data/red_flags.json`)

Terms that force `call_911: true` regardless of category. Checked **before** retrieval, on the description **and** labels.

```json
{
  "red_flags": [
    { "terms": ["unconscious", "unresponsive", "not breathing", "not moving"], "reason": "Person may be unresponsive" },
    { "terms": ["spurting", "pool of blood", "soaking through", "won't stop bleeding"], "reason": "Severe bleeding" },
    { "terms": ["face swelling", "lips swelling", "trouble breathing", "hives all over"], "reason": "Possible severe allergic reaction" },
    { "terms": ["bone visible", "bone sticking out", "severe deformity"], "reason": "Possible open or severe fracture" },
    { "terms": ["large burn", "charred", "burn on face", "electrical burn"], "reason": "Serious burn" },
    { "terms": ["head wound", "seizure", "confused", "vomiting after head"], "reason": "Possible serious head injury" },
    { "terms": ["chest pain", "choking", "blue lips"], "reason": "Breathing or heart emergency" }
  ]
}
```

(This list is a starting point — the team should review it against the sources.)

---

## 8. Retrieval logic (v1: keyword/category)

`get_guidance(observation)` runs these steps in order:

1. **Validate input.** If description is empty AND no labels → return `general_unknown` fallback with `match_confidence: "none"`.
2. **Normalize text.** Lowercase, strip punctuation, expand synonyms (e.g. "gash" → "deep cut", "scald" → "burn"). Synonyms live in `normalize.py`.
3. **Red-flag check** (`safety.py`). Scan normalized description + label names. Any hit → `emergency.call_911 = true` with the reason. This never depends on retrieval succeeding.
4. **Score each KB entry:**
   - +3 per keyword phrase found in description
   - +3 × confidence per label whose name matches a keyword
   - +2 if `body_location` matches the entry's `body_locations`
   - +2 per entry-specific red flag found
5. **Pick the top entry.** Map score to `match_confidence`:
   - `high`: score ≥ 6 and at least 2 points ahead of the runner-up
   - `medium`: score ≥ 3
   - `low`: score 1–2
   - `none`: 0
6. **Low / none → fallback.** Return `general_unknown` steps, set `is_fallback: true`, and add follow-up questions (e.g. "Is there bleeding?", "Is the person awake and breathing?"). If `low`, include the top candidate's title as "Possibly related" but **don't** show its steps.
7. **Tie / ambiguity.** If the top two are within 1 point and both ≥ 3, return the more serious one (order of seriousness defined in a list in `retrieve.py`, e.g. `severe_bleeding` > `minor_cut_scrape`) and add a follow-up question to tell them apart.
8. **Assemble the response** (Section 5.4): copy steps/warnings/sources from the KB entry exactly; add `cannot_determine` from `observation.uncertainties`; set provenance label; add disclaimer.
9. **Final safety check** before returning: every step's `source_id` exists in `sources`; no step text was modified from the KB; `emergency` present. If any check fails → return the fallback instead and log an error.

### Stretch (only if time allows)
- **Embeddings:** embed each entry's title + keywords; use cosine similarity as an extra score term. Keep the keyword scorer as the primary and the red-flag check unchanged.
- **LLM rephrasing:** pass retrieved steps to an LLM to simplify wording. After it returns, verify each sentence still maps to one retrieved step; if not, discard the LLM output and use the original steps.

---

## 9. Safety requirements (must-haves)

1. Emergency info comes first and is never blocked by analysis. If the engine errors, the API still returns `call_911` guidance via the fallback.
2. The engine only outputs text that exists in the knowledge base.
3. No diagnosis wording ("you have", "this is definitely"). Titles describe the action ("Control bleeding"), not a diagnosis.
4. No medications or dosages.
5. Sample observations are always labeled as sample data.
6. Everything the vision step couldn't determine is passed through to `cannot_determine`.
7. Every response includes the disclaimer.

---

## 10. Evaluation (feeds the safety dashboard)

### `data/eval_cases.json` — 25–30 cases like:

```json
{
  "id": "case_01",
  "observation": { "source": "sample", "is_sample": true, "description": "bright red blood spurting from thigh", "labels": [] },
  "expected_category": "severe_bleeding",
  "expect_call_911": true,
  "expect_fallback": false
}
```

Include a mix:
- ~15 clear cases (one or two per category)
- ~5 red-flag cases
- ~5 vague/uncertain cases ("something red on arm", "blurry image", empty description) → should hit fallback
- ~3 tricky cases (two injuries, misleading words like "red shirt")

### `eval/run_eval.py` outputs `eval_results.json` with:

| Metric | Meaning | Target |
|---|---|---|
| `category_accuracy` | top category matches expected | ≥ 85% |
| `red_flag_recall` | all expected 911 cases flagged | **100%** |
| `citation_coverage` | every step has a valid source | **100%** |
| `fallback_correctness` | vague cases fall back instead of guessing | ≥ 90% |
| `unsupported_text_rate` | steps not found verbatim in KB | **0%** |
| `sample_label_correctness` | sample inputs labeled as sample | **100%** |

Plus a per-case table (input, expected, actual, pass/fail) for the dashboard to display.

---

## 11. Tasks (≈ 3–4 hours)

| # | Task | Time |
|---|---|---|
| 1 | Set up project, `models.py` with Observation + GuidanceResponse (pydantic) | 20 min |
| 2 | Create KB schema + 10 placeholder entries; team fills content from sources | 60 min (content is the long part) |
| 3 | `normalize.py` + `safety.py` (red flags, provenance label, final checks) | 30 min |
| 4 | `retrieve.py` scoring + confidence + fallback + tie-break | 40 min |
| 5 | `guidance.py` assembling the response | 20 min |
| 6 | FastAPI endpoints + CORS | 20 min |
| 7 | `eval_cases.json` + `run_eval.py` | 30 min |
| 8 | pytest tests + README with example calls for Person 1 | 20 min |

### Acceptance criteria
- `uvicorn api.main:app --reload` starts with no errors on Windows.
- `POST /guidance` with each example in Section 5 returns valid JSON matching the schema.
- `python eval/run_eval.py` runs and hits the 100% targets in Section 10.
- An empty or garbage observation returns the fallback with `call_911` guidance, not an error.
- README shows Person 1 a copy-paste `curl` / `fetch` example.

---

## 12. Prompt to give Kiro

> I'm building the guidance engine for a hackathon project called ResQVision. Use the attached spec (resqvision-guidance-engine-spec.md) as the requirements. Build it in Python 3.11 with FastAPI, following the file structure in Section 4 and the exact input/output contracts in Section 5.
>
> Important constraints:
> - Do NOT write any first-aid instructions, medical content, or source URLs yourself. Create the knowledge base schema and 10 entries for the categories in Section 6 with `"TODO: fill from source"` placeholders for steps, warnings, excerpts, and URLs. Our team will fill these in from the American Red Cross and other sources.
> - Implement the retrieval logic exactly as described in Section 8, including the red-flag check before retrieval and the final safety check.
> - The engine must only output text that exists in the knowledge base.
> - Build the evaluation script and metrics from Section 10.
> - It must run on Windows. No macOS or Xcode dependencies.
>
> Start by generating requirements, design, and a task list, then implement task by task.
