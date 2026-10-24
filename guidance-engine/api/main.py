"""FastAPI app exposing the guidance engine over HTTP (spec Section 5.2).

Endpoints:
  POST /guidance    -> GuidanceResponse
  GET  /categories  -> supported injury categories
  GET  /health      -> {"status": "ok", "kb_entries": N}
  GET  /eval        -> latest evaluation results (for the dashboard)

CORS is enabled so a web/Expo/iOS client can call it.

Run:  uvicorn api.main:app --reload   (from the guidance-engine/ directory)
"""

from __future__ import annotations

import json
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from engine.guidance import get_guidance
from engine.models import GuidanceResponse, Observation
from engine.retrieve import list_categories, load_knowledge_base

app = FastAPI(
    title="ResQVision Guidance Engine",
    version="0.1.0",
    description=(
        "Returns source-cited first-aid guidance from a curated knowledge "
        "base. Never diagnoses, never invents medical text."
    ),
)

# For a hackathon we allow all origins; tighten before any real deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

EVAL_RESULTS_PATH = Path(__file__).resolve().parent.parent / "eval" / "eval_results.json"


@app.post("/guidance", response_model=GuidanceResponse)
def guidance(observation: Observation) -> GuidanceResponse:
    """Main call. Body = Observation JSON. Returns GuidanceResponse JSON."""
    return get_guidance(observation)


@app.get("/categories")
def categories():
    """List the supported injury categories."""
    kb = load_knowledge_base()
    return {"categories": list_categories(kb)}


@app.get("/health")
def health():
    """Liveness + knowledge-base size."""
    kb = load_knowledge_base()
    return {"status": "ok", "kb_entries": len(kb)}


@app.get("/eval")
def eval_results():
    """Return the latest evaluation results, if run (for the dashboard)."""
    if EVAL_RESULTS_PATH.exists():
        with open(EVAL_RESULTS_PATH, "r", encoding="utf-8") as fh:
            return json.load(fh)
    return {
        "status": "not_run",
        "message": "Run `python eval/run_eval.py` to generate results.",
    }
