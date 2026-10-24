"""get_guidance() — the main entry point (spec Section 5.1 / Section 8).

Assembles a GuidanceResponse by copying steps, warnings, and sources VERBATIM
from the matched knowledge-base entry. The engine never writes or modifies
medical text. If anything goes wrong it degrades to the safe fallback, which
always includes emergency guidance.
"""

from __future__ import annotations

import logging
from functools import lru_cache
from typing import List, Optional

from . import __version__
from .models import (
    GuidanceResponse,
    Observation,
    Source,
    Step,
)
from .retrieve import (
    RetrievalResult,
    get_fallback_entry,
    load_knowledge_base,
    retrieve,
)
from .safety import (
    DISCLAIMER,
    build_emergency,
    build_provenance,
    detect_red_flag,
    load_red_flags,
    passes_final_safety_check,
)

logger = logging.getLogger("resqvision.guidance")


@lru_cache(maxsize=1)
def _kb():
    return load_knowledge_base()


@lru_cache(maxsize=1)
def _red_flags():
    return load_red_flags()


def _steps_from_entry(entry: dict) -> List[Step]:
    return [
        Step(order=s["order"], text=s["text"], source_id=s["source_id"])
        for s in entry.get("steps", [])
    ]


def _sources_from_entry(entry: dict) -> List[Source]:
    return [Source(**s) for s in entry.get("sources", [])]


def _assemble(
    observation: Observation,
    entry: dict,
    result: RetrievalResult,
    call_911: bool,
    reason: Optional[str],
) -> GuidanceResponse:
    """Build a GuidanceResponse from a chosen KB entry (verbatim content)."""
    follow_ups = list(entry.get("follow_up_questions", []))
    if result.tie_break_note:
        follow_ups.append(result.tie_break_note)
    if result.possibly_related_title:
        follow_ups.append(
            f"Possibly related: {result.possibly_related_title}."
        )

    return GuidanceResponse(
        emergency=build_emergency(call_911, reason),
        category=entry["category"],
        match_confidence=result.confidence,
        title=entry["title"],
        steps=_steps_from_entry(entry),
        warnings=list(entry.get("warnings", [])),
        sources=_sources_from_entry(entry),
        observation_provenance=build_provenance(observation),
        cannot_determine=list(observation.uncertainties),
        follow_up_questions=follow_ups,
        disclaimer=DISCLAIMER,
        is_fallback=result.is_fallback,
        engine_version=__version__,
    )


def _fallback_response(
    observation: Observation,
    confidence: str,
    call_911: bool,
    reason: Optional[str],
    possibly_related_title: Optional[str] = None,
    tie_break_note: Optional[str] = None,
) -> GuidanceResponse:
    entry = get_fallback_entry(_kb())
    result = RetrievalResult(
        entry=entry,
        confidence=confidence,
        is_fallback=True,
        possibly_related_title=possibly_related_title,
        tie_break_note=tie_break_note,
    )
    return _assemble(observation, entry, result, call_911, reason)


def get_guidance(observation: Observation) -> GuidanceResponse:
    """Main entry point: Observation -> GuidanceResponse.

    Order (spec Section 8):
      1. red-flag check (before retrieval, never blocked by it)
      2. retrieve best entry / fallback
      3. assemble verbatim from KB
      4. final safety check; on any failure, return the safe fallback
    """
    kb = _kb()
    red_flags = _red_flags()

    # Step: red-flag check first, so emergency guidance is never lost.
    call_911, reason = detect_red_flag(observation, red_flags)

    try:
        result = retrieve(kb, observation)

        if result.is_fallback or result.entry is None:
            response = _fallback_response(
                observation,
                confidence=result.confidence,
                call_911=call_911,
                reason=reason,
                possibly_related_title=result.possibly_related_title,
                tie_break_note=result.tie_break_note,
            )
        else:
            response = _assemble(
                observation, result.entry, result, call_911, reason
            )

        ok, why = passes_final_safety_check(response)
        if not ok:
            logger.error("final safety check failed (%s); using fallback", why)
            response = _fallback_response(
                observation,
                confidence="none",
                call_911=call_911,
                reason=reason,
            )
        return response

    except Exception:  # noqa: BLE001 - must never leak an error to the caller
        logger.exception("guidance pipeline error; returning safe fallback")
        # Even if retrieval blew up, still return emergency-aware fallback.
        try:
            return _fallback_response(
                observation,
                confidence="none",
                call_911=call_911,
                reason=reason,
            )
        except Exception:  # noqa: BLE001 - last-resort hard-coded safe response
            logger.exception("fallback assembly failed; hard-coded response")
            return _hardcoded_emergency_response(observation, call_911, reason)


def _hardcoded_emergency_response(
    observation: Observation, call_911: bool, reason: Optional[str]
) -> GuidanceResponse:
    """Absolute last resort if even the KB fallback cannot be loaded.

    Contains no medical instructions — only the emergency escalation and
    disclaimer, which are safety scaffolding, not first-aid content.
    """
    return GuidanceResponse(
        emergency=build_emergency(True, reason or "Unable to analyze safely"),
        category="general_unknown",
        match_confidence="none",
        title="General safety guidance",
        steps=[],
        warnings=[],
        sources=[],
        observation_provenance=build_provenance(observation),
        cannot_determine=list(observation.uncertainties),
        follow_up_questions=[
            "Is there bleeding?",
            "Is the person awake and breathing?",
            "Is anyone in immediate danger?",
        ],
        disclaimer=DISCLAIMER,
        is_fallback=True,
        engine_version=__version__,
    )
