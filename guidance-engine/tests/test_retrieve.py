"""Tests for the retrieval logic (spec Section 8)."""

from engine.models import Label, Observation
from engine.retrieve import (
    confidence_for,
    load_knowledge_base,
    retrieve,
    score_entry,
)


def _obs(description="", labels=None, body_location=None):
    return Observation(
        source="sample",
        is_sample=True,
        description=description,
        labels=labels or [],
        body_location=body_location,
    )


def test_kb_loads_with_fallback():
    kb = load_knowledge_base()
    ids = {e["id"] for e in kb}
    assert "general_unknown" in ids
    assert len(kb) >= 10


def test_keyword_scoring_matches_description():
    kb = load_knowledge_base()
    bleeding = next(e for e in kb if e["id"] == "severe_bleeding")
    score = score_entry(bleeding, _obs(description="deep cut, lots of blood"))
    assert score >= 3


def test_label_confidence_contributes_to_score():
    kb = load_knowledge_base()
    burn = next(e for e in kb if e["id"] == "burn_thermal")
    score = score_entry(
        burn, _obs(description="", labels=[Label(name="burn", confidence=1.0)])
    )
    assert score >= 3


def test_confidence_tiers():
    assert confidence_for(7, 1) == "high"      # >=6 and >=2 ahead
    assert confidence_for(6, 5) == "medium"    # >=6 but not 2 ahead
    assert confidence_for(3, 0) == "medium"
    assert confidence_for(2, 0) == "low"
    assert confidence_for(0, 0) == "none"


def test_empty_observation_is_fallback():
    kb = load_knowledge_base()
    result = retrieve(kb, _obs(description="", labels=[]))
    assert result.is_fallback
    assert result.confidence == "none"


def test_clear_bleeding_case_matches():
    kb = load_knowledge_base()
    result = retrieve(
        kb,
        _obs(
            description="deep cut on forearm, blood soaking through, spurting",
            labels=[Label(name="bleeding", confidence=0.9)],
        ),
    )
    assert not result.is_fallback
    assert result.entry["id"] == "severe_bleeding"
    assert result.confidence in ("high", "medium")


def test_body_location_bonus():
    kb = load_knowledge_base()
    nose = next(e for e in kb if e["id"] == "nosebleed")
    with_loc = score_entry(nose, _obs(description="nosebleed", body_location="nose"))
    without_loc = score_entry(nose, _obs(description="nosebleed"))
    assert with_loc > without_loc
