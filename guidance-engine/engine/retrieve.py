"""Knowledge-base loading and keyword/category retrieval (spec Section 8).

v1 is pure Python, no ML. Scoring is deterministic and explainable.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from .models import Observation
from .normalize import normalize_labels, normalize_text

logger = logging.getLogger("resqvision.retrieve")

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
KB_PATH = DATA_DIR / "knowledge_base.json"

FALLBACK_CATEGORY = "general_unknown"

# Seriousness ordering for tie-breaking (most serious first). Used when the
# top two candidates are within 1 point and both >= 3 (spec Section 8 step 7).
SERIOUSNESS_ORDER = [
    "severe_bleeding",
    "head_injury",
    "burn_chemical",
    "eye_injury",
    "burn_thermal",
    "sprain_fracture",
    "bite_sting",
    "nosebleed",
    "minor_cut_scrape",
    "general_unknown",
]


class KnowledgeBaseError(Exception):
    """Raised when the knowledge base fails structural validation."""


@dataclass
class ScoredEntry:
    entry: dict
    score: float


def load_knowledge_base(path: Path = KB_PATH) -> List[dict]:
    """Load and structurally validate the KB.

    Refuses to load entries whose step source_ids are not present in that
    entry's own sources. Logs a warning for entries with reviewed=false.
    """
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    entries = data.get("entries", [])

    validated: List[dict] = []
    for entry in entries:
        entry_id = entry.get("id", "<unknown>")
        source_ids = {src.get("id") for src in entry.get("sources", [])}
        for step in entry.get("steps", []):
            if step.get("source_id") not in source_ids:
                raise KnowledgeBaseError(
                    f"entry '{entry_id}' has a step with source_id "
                    f"'{step.get('source_id')}' not found in its sources"
                )
        if not entry.get("reviewed", False):
            logger.warning(
                "KB entry '%s' is not reviewed yet (reviewed=false); its "
                "content may contain TODO placeholders.",
                entry_id,
            )
        validated.append(entry)

    if not any(e.get("id") == FALLBACK_CATEGORY for e in validated):
        raise KnowledgeBaseError(
            f"knowledge base must contain a '{FALLBACK_CATEGORY}' fallback "
            "entry"
        )
    return validated


def score_entry(entry: dict, observation: Observation) -> float:
    """Score a single KB entry against the observation (spec Section 8.4).

    +3 per keyword phrase found in description
    +3 * confidence per label whose name matches a keyword
    +2 if body_location matches the entry's body_locations
    +2 per entry-specific red flag found in description
    """
    score = 0.0
    desc = normalize_text(observation.description)
    keywords = [normalize_text(k) for k in entry.get("keywords", [])]

    # +3 per keyword phrase found in description
    for kw in keywords:
        if kw and kw in desc:
            score += 3.0

    # +3 * confidence per label whose name matches a keyword
    for label in observation.labels:
        label_norm = normalize_text(label.name)
        for kw in keywords:
            if kw and kw in label_norm:
                score += 3.0 * label.confidence
                break  # count a label at most once

    # +2 if body_location matches the entry's body_locations
    body_locs = [normalize_text(b) for b in entry.get("body_locations", [])]
    if observation.body_location:
        loc = normalize_text(observation.body_location)
        if loc and loc in body_locs:
            score += 2.0

    # +2 per entry-specific red flag found in description
    for rf in entry.get("red_flags", []):
        if normalize_text(rf) in desc:
            score += 2.0

    return score


def _seriousness_rank(category: str) -> int:
    try:
        return SERIOUSNESS_ORDER.index(category)
    except ValueError:
        return len(SERIOUSNESS_ORDER)


def rank_entries(
    kb: List[dict], observation: Observation
) -> List[ScoredEntry]:
    """Score every entry and return them sorted by score descending.

    Fallback entry is excluded from scoring (it is only used as a fallback).
    """
    scored = [
        ScoredEntry(entry=e, score=score_entry(e, observation))
        for e in kb
        if e.get("id") != FALLBACK_CATEGORY
    ]
    scored.sort(key=lambda s: s.score, reverse=True)
    return scored


def confidence_for(score: float, runner_up: float) -> str:
    """Map a score (and the runner-up's score) to a confidence tier."""
    if score >= 6 and (score - runner_up) >= 2:
        return "high"
    if score >= 3:
        return "medium"
    if score >= 1:
        return "low"
    return "none"


@dataclass
class RetrievalResult:
    entry: Optional[dict]          # best matching entry (None -> fallback)
    confidence: str                # high | medium | low | none
    is_fallback: bool
    possibly_related_title: Optional[str]  # shown on "low" without steps
    tie_break_note: Optional[str]  # follow-up to disambiguate a close tie


def has_signal(observation: Observation) -> bool:
    """True if there is any description text or any labels to work with."""
    return bool(observation.description.strip()) or bool(observation.labels)


def retrieve(kb: List[dict], observation: Observation) -> RetrievalResult:
    """Run the retrieval pipeline (spec Section 8 steps 4-7)."""
    # Step 1 (validate): no signal -> fallback with confidence "none".
    if not has_signal(observation):
        return RetrievalResult(
            entry=None,
            confidence="none",
            is_fallback=True,
            possibly_related_title=None,
            tie_break_note=None,
        )

    ranked = rank_entries(kb, observation)
    top = ranked[0] if ranked else None
    runner_up_score = ranked[1].score if len(ranked) > 1 else 0.0

    if top is None or top.score == 0:
        return RetrievalResult(
            entry=None,
            confidence="none",
            is_fallback=True,
            possibly_related_title=None,
            tie_break_note=None,
        )

    confidence = confidence_for(top.score, runner_up_score)

    # Step 7: tie / ambiguity. If the top two are within 1 point and both
    # >= 3, prefer the more serious one and add a disambiguation note.
    tie_break_note: Optional[str] = None
    if (
        len(ranked) > 1
        and top.score >= 3
        and ranked[1].score >= 3
        and abs(top.score - ranked[1].score) <= 1
    ):
        a, b = top.entry, ranked[1].entry
        more_serious = (
            a
            if _seriousness_rank(a["category"]) <= _seriousness_rank(b["category"])
            else b
        )
        less = b if more_serious is a else a
        top = ScoredEntry(entry=more_serious, score=top.score)
        tie_break_note = (
            f"This could also be '{less['title']}'. "
            "Pick the most serious one if unsure."
        )

    # Step 6: low / none -> fallback. On "low", surface the candidate title
    # as "possibly related" but do NOT show its steps.
    if confidence in ("low", "none"):
        return RetrievalResult(
            entry=None,
            confidence=confidence,
            is_fallback=True,
            possibly_related_title=(
                top.entry["title"] if confidence == "low" else None
            ),
            tie_break_note=tie_break_note,
        )

    return RetrievalResult(
        entry=top.entry,
        confidence=confidence,
        is_fallback=False,
        possibly_related_title=None,
        tie_break_note=tie_break_note,
    )


def get_fallback_entry(kb: List[dict]) -> dict:
    """Return the general_unknown fallback entry."""
    for entry in kb:
        if entry.get("id") == FALLBACK_CATEGORY:
            return entry
    raise KnowledgeBaseError("fallback entry not found")


def list_categories(kb: List[dict]) -> List[Dict[str, str]]:
    """Return [{id, title}] for every KB entry (for GET /categories)."""
    return [{"id": e["id"], "title": e["title"]} for e in kb]
