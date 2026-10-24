"""Safety layer: red-flag detection, provenance labels, and the final
safety check that runs before any response is returned.

Design rule (spec Section 9): emergency info comes first and is never blocked
by analysis. The red-flag check does not depend on retrieval succeeding.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import List, Optional, Tuple

from .models import (
    Emergency,
    GuidanceResponse,
    Observation,
    ObservationProvenance,
)
from .normalize import normalize_labels, normalize_text

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
RED_FLAGS_PATH = DATA_DIR / "red_flags.json"

SAMPLE_LABEL = "SAMPLE DATA — not a real camera analysis."
PROVENANCE_LABELS = {
    "vision_model": "Based on camera analysis — may be incomplete",
    "user_text": "Based on what you typed",
    "sample": SAMPLE_LABEL,
}

DISCLAIMER = (
    "This is first-aid guidance, not a medical diagnosis. When in doubt, "
    "call 911."
)

# Default emergency message used whenever call_911 is true.
EMERGENCY_CALL_MESSAGE = (
    "Call 911 now. Start these steps while you wait or have someone else call."
)
NO_EMERGENCY_MESSAGE = (
    "If the situation gets worse or you are unsure, call 911."
)


def load_red_flags(path: Path = RED_FLAGS_PATH) -> List[dict]:
    """Load the red-flag term groups from disk."""
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    return data.get("red_flags", [])


def detect_red_flag(
    observation: Observation, red_flags: List[dict]
) -> Tuple[bool, Optional[str]]:
    """Scan the normalized description AND label names for any red-flag term.

    Returns (call_911, reason). Runs before retrieval and never raises.
    """
    haystack_parts = [normalize_text(observation.description)]
    haystack_parts.extend(
        normalize_labels([label.name for label in observation.labels])
    )
    haystack = " ".join(part for part in haystack_parts if part)

    for group in red_flags:
        for term in group.get("terms", []):
            if normalize_text(term) in haystack:
                return True, group.get("reason")
    return False, None


def build_emergency(call_911: bool, reason: Optional[str]) -> Emergency:
    """Emergency block is always present; message depends on call_911."""
    if call_911:
        return Emergency(
            call_911=True,
            reason=reason,
            message=EMERGENCY_CALL_MESSAGE,
        )
    return Emergency(call_911=False, reason=None, message=NO_EMERGENCY_MESSAGE)


def build_provenance(observation: Observation) -> ObservationProvenance:
    """Provenance label; sample inputs always get the SAMPLE DATA label."""
    if observation.is_sample or observation.source == "sample":
        label = SAMPLE_LABEL
    else:
        label = PROVENANCE_LABELS.get(observation.source, SAMPLE_LABEL)
    return ObservationProvenance(
        source=observation.source,
        is_sample=observation.is_sample,
        label=label,
    )


def passes_final_safety_check(response: GuidanceResponse) -> Tuple[bool, str]:
    """Verify invariants before returning (spec Section 8 step 9 / Section 9).

    - every step's source_id exists in sources
    - emergency block is present (guaranteed by the type, checked defensively)
    - disclaimer is present

    Returns (ok, reason_if_not_ok).
    """
    source_ids = {src.id for src in response.sources}
    for step in response.steps:
        if step.source_id not in source_ids:
            return False, (
                f"step {step.order} references unknown source_id "
                f"'{step.source_id}'"
            )
    if response.emergency is None:  # defensive; type says non-optional
        return False, "missing emergency block"
    if not response.disclaimer:
        return False, "missing disclaimer"
    return True, ""
