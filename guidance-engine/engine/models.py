"""Pydantic models for the guidance engine input (Observation) and output
(GuidanceResponse).

These mirror the interface contract in Section 5 of
resqvision-guidance-engine-spec.md exactly. Person 1 (the iOS app) builds an
Observation and receives a GuidanceResponse.
"""

from __future__ import annotations

from typing import List, Literal, Optional

# The real dependency is pydantic v2 (pinned in requirements.txt). On machines
# where pydantic is installed (e.g. your Mac / CI), it is used directly. In the
# offline hackathon sandbox where pydantic cannot be installed, we fall back to
# a tiny stdlib-only shim that provides the same BaseModel/Field surface used by
# this module (construction, type coercion, basic validation, model_dump, and
# dict(**model)). This keeps the engine and its tests runnable everywhere
# without changing the deployed behavior.
try:  # pragma: no cover - exercised implicitly by whichever path is active
    from pydantic import BaseModel, Field  # type: ignore

    _USING_PYDANTIC = True
except ModuleNotFoundError:  # pragma: no cover
    from ._compat_models import BaseModel, Field  # type: ignore

    _USING_PYDANTIC = False

# ---------------------------------------------------------------------------
# Input: Observation (Section 5.3)
# ---------------------------------------------------------------------------


class Label(BaseModel):
    """A label produced by a vision model, with a confidence in [0, 1]."""

    name: str
    confidence: float = Field(ge=0.0, le=1.0)


ObservationSource = Literal["vision_model", "sample", "user_text"]


class Observation(BaseModel):
    """What the camera/vision step saw. The engine reads only this text.

    `description` may be empty if `labels` are present. If both are empty the
    engine returns the general fallback (never an error).
    """

    source: ObservationSource
    is_sample: bool
    description: str = ""
    labels: List[Label] = Field(default_factory=list)
    body_location: Optional[str] = None
    uncertainties: List[str] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Output: GuidanceResponse (Section 5.4)
# ---------------------------------------------------------------------------


class Emergency(BaseModel):
    """Always present. `call_911` is False when no red flags were detected."""

    call_911: bool
    reason: Optional[str] = None
    message: str


class Step(BaseModel):
    """One ordered first-aid step. `source_id` must exist in `sources`."""

    order: int
    text: str
    source_id: str


class Source(BaseModel):
    """A cited source. Content is filled and verified by the human team."""

    id: str
    publisher: str
    title: str
    url: str
    excerpt: str
    retrieved_date: str


class ObservationProvenance(BaseModel):
    """Tells the user where the observation came from and how much to trust it.

    For sample inputs the label must say "SAMPLE DATA — not a real camera
    analysis." (enforced in safety.py).
    """

    source: ObservationSource
    is_sample: bool
    label: str


MatchConfidence = Literal["high", "medium", "low", "none"]


class GuidanceResponse(BaseModel):
    emergency: Emergency
    category: str
    match_confidence: MatchConfidence
    title: str
    steps: List[Step] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)
    sources: List[Source] = Field(default_factory=list)
    observation_provenance: ObservationProvenance
    cannot_determine: List[str] = Field(default_factory=list)
    follow_up_questions: List[str] = Field(default_factory=list)
    disclaimer: str
    is_fallback: bool
    engine_version: str
